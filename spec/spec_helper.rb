require 'simplecov'
SimpleCov.start 'rails'

require 'rubygems'

# Require pry when we're not inside Travis-CI
require 'pry' unless ENV['CI']

# This spec_helper.rb is being used by the custom engines in engines/. The engines are not set up to
# use Knapsack, and this provides the option to disable it when running the tests in CI services.
unless ENV['DISABLE_KNAPSACK']
  require 'knapsack'
  Knapsack.tracker.config(enable_time_offset_warning: false) unless ENV['CI']
  Knapsack::Adapters::RSpecAdapter.bind
end

ENV["RAILS_ENV"] ||= 'test'
require_relative "../config/environment"
require 'rspec/rails'
require 'capybara'
require 'database_cleaner'
require 'rspec/retry'
require 'paper_trail/frameworks/rspec'

require 'webdrivers'

# Allow connections to phantomjs/selenium whilst raising errors
# when connecting to external sites
require 'webmock/rspec'
WebMock.enable!
WebMock.disable_net_connect!({
  allow_localhost: true,
  allow: 'chromedriver.storage.googleapis.com'
})

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/capybara_ext'
require 'spree/api/testing_support/setup'
require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/preferences'
require 'support/api_helper'

# Capybara config
require 'selenium-webdriver'
Capybara.javascript_driver = :chrome

Capybara.register_driver :chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new(
    args: %w[headless disable-gpu no-sandbox window-size=1280,768]
  )
  Capybara::Selenium::Driver
    .new(app, browser: :chrome, options: options)
    .tap { |driver| driver.browser.download_path = DownloadsHelper.path.to_s }
end

Capybara.default_max_wait_time = 30

require "paperclip/matchers"

# Override setting in Spree engine: Spree::Core::MailSettings
ActionMailer::Base.default_url_options[:host] = 'test.host'

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Filters
  config.filter_run_excluding skip: true, future: true, to_figure_out: true

  # Retry
  config.verbose_retry = true

  # DatabaseCleaner
  config.before(:suite)          { DatabaseCleaner.clean_with :deletion, except: ['spree_countries', 'spree_states'] }
  config.before(:each)           { DatabaseCleaner.strategy = :transaction }
  config.before(:each, js: true) { DatabaseCleaner.strategy = :deletion, { except: ['spree_countries', 'spree_states'] } }
  config.before(:each)           { DatabaseCleaner.start }
  config.after(:each)            { DatabaseCleaner.clean }
  config.after(:each, js: true) do
    Capybara.reset_sessions!
    RackRequestBlocker.wait_for_requests_complete
  end

  def restart_phantomjs
    Capybara.send('session_pool').values
      .select { |s| s.driver.is_a?(Capybara::Selenium::Driver) }
      .each { |s| s.driver.reset! }
  end

  config.before(:all) { restart_phantomjs }

  # Geocoding
  config.before(:each) { allow_any_instance_of(Spree::Address).to receive(:geocode).and_return([1, 1]) }

  default_country_id = Spree::Config[:default_country_id]
  checkout_zone = Spree::Config[:checkout_zone]
  currency = Spree::Config[:currency]
  # Ensure we start with consistent config settings
  config.before(:each) do
    reset_spree_preferences do |spree_config|
      # These are all settings that differ from Spree's defaults
      spree_config.default_country_id = default_country_id
      spree_config.checkout_zone = checkout_zone
      spree_config.currency = currency
      spree_config.shipping_instructions = true
      spree_config.auto_capture = true
    end
  end

  # Helpers
  config.include Rails.application.routes.url_helpers
  config.include Spree::UrlHelpers
  config.include Spree::CheckoutHelpers
  config.include Spree::MoneyHelper
  config.include Spree::TestingSupport::ControllerRequests, type: :controller
  config.include Spree::TestingSupport::Preferences
  config.include Devise::TestHelpers, type: :controller
  config.extend  Spree::Api::TestingSupport::Setup, type: :controller
  config.include OpenFoodNetwork::ApiHelper, type: :controller
  config.include OpenFoodNetwork::ControllerHelper, type: :controller
  config.include Features::DatepickerHelper, type: :feature
  config.include OpenFoodNetwork::FeatureToggleHelper
  config.include OpenFoodNetwork::FiltersHelper
  config.include OpenFoodNetwork::EnterpriseGroupsHelper
  config.include OpenFoodNetwork::ProductsHelper
  config.include OpenFoodNetwork::DistributionHelper
  config.include OpenFoodNetwork::HtmlHelper
  config.include ActionView::Helpers::DateHelper
  config.include OpenFoodNetwork::DelayedJobHelper
  config.include OpenFoodNetwork::PerformanceHelper
  config.include DownloadsHelper, type: :feature

  # FactoryBot
  require 'factory_bot_rails'
  config.include FactoryBot::Syntax::Methods

  config.include Paperclip::Shoulda::Matchers

  config.include JsonSpec::Helpers

  # Profiling
  #
  # This code shouldn't be run in normal circumstances. But if you want to know
  # which parts of your code take most time, then you can activate the lines
  # below. Keep in mind that it will slow down the execution time heaps.
  #
  # The PerfTools will write a binary file to the specified path which can then
  # be examined by:
  #
  #   bundle exec pprof.rb --text  /tmp/rspec_profile
  #

  # require 'perftools'
  # config.before :suite do
  #  PerfTools::CpuProfiler.start("/tmp/rspec_profile")
  # end
  #
  # config.after :suite do
  # PerfTools::CpuProfiler.stop
  # end
end
