require 'nokogiri'
require 'selenium-webdriver'
require 'net/http'
require 'fileutils'
require 'open-uri'
require 'json'
require 'timeout'

# Function to install and configure all required dependencies
def install_dependencies
  puts "Installing required dependencies..."

  # Update system packages
  system('sudo apt update')
  system('sudo apt install -y wget unzip')

  # Install Google Chrome
  puts "Installing Google Chrome..."
  system('wget -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb')
  system('sudo apt install -y /tmp/google-chrome-stable_current_amd64.deb')

  # Verify Chrome installation
  chrome_version = `google-chrome --version`.strip
  if chrome_version.empty?
    puts "Google Chrome installation failed. Exiting."
    exit 1
  else
    puts "Google Chrome installed: #{chrome_version}"
  end

  # Install ChromeDriver
  puts "Installing ChromeDriver..."
  chrome_version_match = chrome_version.match(/\d+\./)
  if chrome_version_match.nil?
    puts "Unable to determine Chrome version. Exiting."
    exit 1
  end
  chrome_version_number = chrome_version_match[0].chomp('.')
  chromedriver_url = "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_#{chrome_version_number}"

  begin
    latest_chromedriver_version = URI.open(chromedriver_url).read.strip
    chromedriver_download_url = "https://chromedriver.storage.googleapis.com/#{latest_chromedriver_version}/chromedriver_linux64.zip"
    system("wget -O /tmp/chromedriver_linux64.zip #{chromedriver_download_url}")
    if File.exist?('/tmp/chromedriver_linux64.zip')
      system('unzip -o /tmp/chromedriver_linux64.zip -d /usr/local/bin/')
      system('chmod +x /usr/local/bin/chromedriver')
    else
      raise "ChromeDriver archive not found."
    end
  rescue StandardError => e
    puts "Failed to download or install ChromeDriver: #{e.message}. Trying alternative installation."
    system('sudo apt install -y chromium-driver')
    alternative_version = `chromedriver --version`.strip
    if alternative_version.empty?
      puts "Alternative ChromeDriver installation failed. Exiting."
      exit 1
    else
      puts "Alternative ChromeDriver installed: #{alternative_version}"
    end
  end

  # Verify ChromeDriver installation
  chromedriver_version = `chromedriver --version`.strip
  if chromedriver_version.empty?
    puts "ChromeDriver installation failed. Exiting."
    exit 1
  else
    puts "ChromeDriver installed: #{chromedriver_version}"
  end

  # Install required Ruby gems
  puts "Installing required Ruby gems..."
  system('gem install selenium-webdriver nokogiri')
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
  proxies
end

# Function to rotate user agents
def rotate_user_agents
  [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:89.0) Gecko/20100101 Firefox/89.0'
  ]
end

# Function to crawl and find download links for proxy lists
def find_download_links(driver, max_depth: 3, current_depth: 0)
  return [] if current_depth >= max_depth

  puts "Scanning for download links..."
  links = driver.find_elements(tag_name: 'a').map { |link| link.attribute('href') }.compact

  download_links = links.select { |link| link =~ /proxy.*list.*download|csv|txt/i }

  # Recursively scan other pages for download links
  links.each do |link|
    begin
      driver.navigate.to link
      download_links.concat(find_download_links(driver, max_depth: max_depth, current_depth: current_depth + 1))
    rescue Selenium::WebDriver::Error::WebDriverError
      next
    end
  end

  download_links.uniq
end

# Function to scrape proxies dynamically
def scrape_proxies(website_url, output_file, proxy_list: [], user_agents: [])
  proxies = []

  proxy_list.each_with_index do |proxy, index|
    begin
      # Set up Selenium WebDriver with options
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless') # Run in headless mode
      options.add_argument('--disable-gpu')
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      user_agent = user_agents[index % user_agents.size]
      options.add_argument("--user-agent=\"#{user_agent}\"")
      options.add_argument("--proxy-server=http://#{proxy}")
      puts "Using proxy: #{proxy} with User-Agent: #{user_agent}"

      # Initialize WebDriver
      driver = Selenium::WebDriver.for :chrome, options: options
      driver.navigate.to website_url

      # Find and log download links
      download_links = find_download_links(driver)
      puts "Found download links: #{download_links.join(', ')}"

      # Extract proxy information using adaptive logic
      page_source = driver.page_source
      doc = Nokogiri::HTML(page_source)
      doc.css('table, div, ul').each do |element|
        element.css('tr, li').each do |row|
          ip = row.text.scan(/\b\d{1,3}(?:\.\d{1,3}){3}\b/).first
          port = row.text.scan(/\b\d{2,5}\b/).first
          proxies << "#{ip}:#{port}" if ip && port
        end
      end
    rescue Selenium::WebDriver::Error::WebDriverError => e
      puts "An error occurred with proxy #{proxy}: #{e.message}"
    ensure
      driver&.quit if defined?(driver)
    end

    # Add a delay to prevent overwhelming the server
    sleep(2)
  end

  # Save proxies to output file
  if proxies.empty?
    puts "No proxies found. Ensure the site's structure matches the script's logic."
  else
    File.open(output_file, 'w') do |file|
      proxies.each { |proxy| file.puts(proxy) }
    end
    puts "Scraped #{proxies.size} proxies and saved to #{output_file}."
  end
end

# Main program
def main
  # Install dependencies
  install_dependencies

  # Fetch free proxies
  proxy_list = fetch_proxies_from_web
  user_agents = rotate_user_agents

  # Input: website URL
  puts "Enter the URL of the website to scrape proxies from:"
  website_url = gets.chomp
  output_file = "proxies_output.txt"

  # Run scraper
  scrape_proxies(website_url, output_file, proxy_list: proxy_list, user_agents: user_agents)
end

# Run the main program
main
