require 'nokogiri'
require 'selenium-webdriver'
require 'net/http'
require 'fileutils'
require 'open-uri'
require 'json'
require 'set'
require 'timeout'

class SmartWebCrawler
  def initialize
    @proxies = []
    @user_agents = rotate_user_agents
    @visited_links = Set.new
  end

  # Function to fetch user agents
  def rotate_user_agents
    [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:89.0) Gecko/20100101 Firefox/89.0',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1',
      'Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; WOW64; rv:45.0) Gecko/20100101 Firefox/45.0',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/18.18363',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/91.0.4472.124 Chrome/91.0.4472.124 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Mozilla/5.0 (Linux; U; Android 4.1.1; en-us; Nexus 7 Build/JRO03D) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Safari/534.30',
      'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:50.0) Gecko/20100101 Firefox/50.0',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/601.7.7 (KHTML, like Gecko)',
      'Mozilla/5.0 (Linux; Android 9; Pixel 3 XL Build/PQ3B.190705.003) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.132 Mobile Safari/537.36',
      'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0'
    ]
  end

  # Function to fetch free proxies
  def fetch_proxies_from_web
    puts "Fetching free proxies from the web..."
    uri = URI('https://www.sslproxies.org/')
    response = Net::HTTP.get(uri)
    doc = Nokogiri::HTML(response)

    proxies = doc.css('table tbody tr').map do |row|
      ip = row.css('td:nth-child(1)').text.strip
      port = row.css('td:nth-child(2)').text.strip
      "#{ip}:#{port}" unless ip.empty? || port.empty?
    end.compact

    puts "Fetched #{proxies.size} proxies."
    @proxies = proxies
  end

  # Initialize a Selenium WebDriver
  def initialize_driver(proxy: nil, user_agent: nil)
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument("--user-agent=#{user_agent}") if user_agent
    options.add_argument("--proxy-server=http://#{proxy}") if proxy

    Selenium::WebDriver.for :chrome, options: options
  end

  # Scrape all links from the page
  def scrape_links(driver, max_depth, current_depth = 0)
    return [] if current_depth >= max_depth

    puts "Scraping links at depth #{current_depth}..."
    page_links = driver.find_elements(tag_name: 'a').map { |link| link.attribute('href') }.compact
    new_links = page_links - @visited_links.to_a

    @visited_links.merge(new_links)
    download_links = new_links.select { |link| link =~ /proxy.*list.*download|csv|txt/i }

    new_links.each do |link|
      begin
        driver.navigate.to link
        download_links.concat(scrape_links(driver, max_depth, current_depth + 1))
      rescue Selenium::WebDriver::Error::WebDriverError => e
        puts "Error navigating to #{link}: #{e.message}"
      end
    end

    download_links.uniq
  end

  # Download and save proxies from links
  def download_proxies(download_links, output_file)
    combined_proxies = []

    download_links.each do |link|
      begin
        puts "Downloading proxies from #{link}..."
        proxy_list = URI.open(link).read
        proxy_list.lines.each do |line|
          combined_proxies << line.strip if line =~ /\b\d{1,3}(?:\.\d{1,3}){3}\b:\d{2,5}\b/
        end
      rescue StandardError => e
        puts "Failed to download proxies from #{link}: #{e.message}"
      end
    end

    combined_proxies.uniq!
    File.open(output_file, 'a') { |file| combined_proxies.each { |proxy| file.puts(proxy) } }
    puts "Saved #{combined_proxies.size} proxies to #{output_file}."
  end

  # Scrape proxies from the website using threads for speed
  def scrape_proxies(website_url, output_file)
    threads = []

    # Validate and filter proxies
    @proxies = @proxies.select { |proxy| proxy.is_a?(String) || proxy.nil? }
    proxies_to_use = @proxies.empty? ? [nil] : @proxies

    proxies_to_use.each_with_index do |proxy, index|
      threads << Thread.new do
        begin
          user_agent = @user_agents[index % @user_agents.size]
          puts "Starting thread with proxy: #{proxy.inspect}, User-Agent: #{user_agent}"

          driver = initialize_driver(proxy: proxy, user_agent: user_agent)
          driver.navigate.to website_url

          download_links = scrape_links(driver, max_depth: 3)
          download_proxies(download_links, output_file)
        rescue StandardError => e
          puts "Error in thread with proxy #{proxy}: #{e.message}"
        ensure
          driver&.quit
        end
      end
    end

    threads.each(&:join)
    puts "All threads completed."
  end

  # Main entry point for the crawler
  def run
    fetch_proxies_from_web if @proxies.empty?
    puts "Enter the URL to scrape:"
    website_url = gets.chomp
    output_file = 'proxies_output.txt'

    scrape_proxies(website_url, output_file)
    puts "Crawling completed."
  end
end

# Function to install and configure all required dependencies
def install_dependencies
  puts "Installing required dependencies..."

  # Check if Chrome and ChromeDriver are already installed
  chrome_installed = !`which google-chrome`.empty?
  chromedriver_installed = !`which chromedriver`.empty?

  unless chrome_installed
    # Install Google Chrome
    puts "Installing Google Chrome..."
    system('wget -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb')
    system('sudo apt install -y /tmp/google-chrome-stable_current_amd64.deb')
  else
    puts "Google Chrome is already installed."
  end

  unless chromedriver_installed
    # Install ChromeDriver
    puts "Installing ChromeDriver..."
    chrome_version = `google-chrome --version`.strip.match(/\d+\./).to_s.chomp('.')
    chromedriver_url = "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_#{chrome_version}"

    begin
      latest_chromedriver_version = URI.open(chromedriver_url).read.strip
      chromedriver_download_url = "https://chromedriver.storage.googleapis.com/#{latest_chromedriver_version}/chromedriver_linux64.zip"
      system("wget -O /tmp/chromedriver_linux64.zip #{chromedriver_download_url}")
      system('unzip -o /tmp/chromedriver_linux64.zip -d /usr/local/bin/')
      system('chmod +x /usr/local/bin/chromedriver')
    rescue StandardError => e
      puts "Failed to download or install ChromeDriver: #{e.message}. Trying alternative installation."
      system('sudo apt install -y chromium-driver')
    end
  else
    puts "ChromeDriver is already installed."
  end

  # Install required Ruby gems
  puts "Installing required Ruby gems..."
  system('gem install selenium-webdriver nokogiri')
end

# Run the crawler
install_dependencies
crawler = SmartWebCrawler.new
crawler.run