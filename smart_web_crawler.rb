require 'nokogiri'
require 'selenium-webdriver'
require 'net/http'
require 'fileutils'
require 'open-uri'
require 'json'

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

# Function to scrape proxies dynamically
def scrape_proxies(website_url, output_file, use_proxy: false, proxy_list: [])
  begin
    # Set up Selenium WebDriver with options
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless') # Run in headless mode
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"')

    # Use proxy if specified
    if use_proxy && !proxy_list.empty?
      proxy = proxy_list.sample
      options.add_argument("--proxy-server=http://#{proxy}")
      puts "Using proxy: #{proxy}"
    end

    # Initialize WebDriver
    driver = Selenium::WebDriver.for :chrome, options: options
    driver.navigate.to website_url

    # Wait for JavaScript-rendered content to load
    sleep 5
    page_source = driver.page_source
    driver.quit

    # Parse HTML content with Nokogiri
    doc = Nokogiri::HTML(page_source)

    # Analyze website structure to identify potential proxy data
    puts "Scanning website structure..."
    structure = doc.css('body *').map(&:name).tally
    puts "HTML Element Structure:"
    structure.each { |tag, count| puts "#{tag}: #{count}" }

    # Attempt to extract proxies (adjust selectors dynamically if needed)
    proxies = []
    doc.css('table tbody tr').each do |row|
      ip = row.css('td:nth-child(1)').text.strip
      port = row.css('td:nth-child(2)').text.strip
      proxies << "#{ip}:#{port}" unless ip.empty? || port.empty?
    end

    # Save proxies to output file
    if proxies.empty?
      puts "No proxies found. Ensure the site's structure matches the script's logic."
      return
    end

    File.open(output_file, 'w') do |file|
      proxies.each { |proxy| file.puts(proxy) }
    end

    puts "Scraped #{proxies.size} proxies and saved to #{output_file}."
  rescue Selenium::WebDriver::Error::WebDriverError => e
    puts "An error occurred: #{e.message}"
  ensure
    driver&.quit
  end
end

# Main program
def main
  # Install dependencies
  install_dependencies

  # Fetch free proxies
  proxy_list = fetch_proxies_from_web

  # Input: website URL
  puts "Enter the URL of the website to scrape proxies from:"
  website_url = gets.chomp
  output_file = "proxies_output.txt"

  # Run scraper
  scrape_proxies(website_url, output_file, use_proxy: true, proxy_list: proxy_list)
end

# Run the main program
main
