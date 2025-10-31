# Sanarei Middleware

A Sinatra-based middleware application generated using [Corneal](https://github.com/thebrianemory/corneal), a Sinatra app generator.

## Prerequisites

- Ruby 3.x
- MongoDB (default database)
- Redis (for background jobs)
- Bundler

## MongoDB Installation

### MacOS
```bash
brew tap mongodb/brew
brew install mongodb-community
brew services start mongodb-community
```

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install -y mongodb
sudo systemctl start mongodb
sudo systemctl enable mongodb
```

### Verify MongoDB Installation
```bash
mongo --version
```

## Redis Installation

### MacOS
```bash
brew install redis
brew services start redis
```

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install -y redis-server
sudo systemctl start redis
sudo systemctl enable redis
```

### Verify Redis Installation
```bash
redis-cli ping
# Should return: PONG
```

## Setup

1. Clone the repository:
```bash
git clone git@github.com:sanarei/sanarei-middleware.git
cd sanarei-middleware
```

2. Install dependencies:
```bash
bundle install
```

3. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Ensure MongoDB is running:
```bash
# MacOS
brew services list | grep mongodb

# Linux
sudo systemctl status mongodb
```

## Running the Application

### Using Puma (Recommended for Production)

```bash
bundle exec puma
```

Or with custom configuration:
```bash
bundle exec puma -p 9292 -e production
```

### Using Other Application Servers

#### Shotgun (Development with Auto-reload)
```bash
bundle exec shotgun
```

#### Rackup (Basic Server)
```bash
bundle exec rackup config.ru
```

#### Thin
```bash
gem install thin
bundle exec thin start
```

#### Unicorn
```bash
gem install unicorn
bundle exec unicorn -c config/unicorn.rb
```

## Background Jobs with Sidekiq

This project uses Sidekiq for background job processing. Redis is required and must be running before you start Sidekiq.

- Redis URL: set via the REDIS_URL environment variable (defaults to redis://localhost:6379/0).
- Sidekiq client/server config: see config/initializers/sidekiq.rb
- Queues and concurrency: see config/sidekiq.yml (default and website_fetcher queues are defined).

### Start Sidekiq

Run Sidekiq in a separate terminal alongside your web server:
```bash
bundle exec sidekiq -r ./config/environment -C config/sidekiq.yml
```

Common variations:
- Specify environment: RACK_ENV=production bundle exec sidekiq -r ./config/environment -C config/sidekiq.yml
- Specify queues: bundle exec sidekiq -r ./config/environment -q website_fetcher -q default

### Enqueuing Jobs

An example worker is provided at app/workers/website_fetcher_worker.rb. You can enqueue jobs from anywhere after the app environment is loaded.

Basic usage:
```ruby
WebsiteFetcherWorker.perform_async('https://example.com')
```

With options (headers, timeouts, etc.):
```ruby
options = {
  headers: { 'User-Agent' => 'MyBot/1.0' },
  timeout: 10,
  follow_redirects: true
}
WebsiteFetcherWorker.perform_async('https://example.com', options)
```

Schedule for later:
```ruby
WebsiteFetcherWorker.perform_in(5.minutes, 'https://example.com')
WebsiteFetcherWorker.perform_at(1.hour.from_now, 'https://example.com')
```

See app/workers/example_usage.rb for additional examples and controller usage patterns.

### Optional: Sidekiq Web UI (development)

To view the job dashboard in development, you can mount the Sidekiq Web UI. Add the following to config.ru (and only enable in trusted environments):
```ruby
require 'sidekiq/web'
# Optionally add basic auth for protection in non-dev environments
# Sidekiq::Web.use Rack::Auth::Basic do |user, pass|
#   [user, pass] == [ENV['SIDEKIQ_USER'], ENV['SIDEKIQ_PASSWORD']]
# end

map '/sidekiq' do
  run Sidekiq::Web
end
```
Then start your app server and visit http://localhost:9292/sidekiq

### Troubleshooting

- Ensure Redis is running: redis-cli ping should return PONG.
- Verify REDIS_URL matches your Redis instance (default is redis://localhost:6379/0).
- Check Sidekiq logs for errors and the retries tab for failed jobs.
- Make sure you are pushing to a queue that your Sidekiq process is listening to (see config/sidekiq.yml or pass -q flags).

## Development

### Running Tests
```bash
bundle exec rspec
```

### Linting
```bash
bundle exec rubocop
```

### Interactive Console
```bash
bundle exec pry -r ./config/environment
# or
bundle exec tux # tux has not been supported for a while, use pry instead
```

## Project Structure

This application follows the standard Sinatra MVC pattern:

- `app/controllers/` - Application controllers
- `app/models/` - Mongoid models
- `config/` - Configuration files
- `config.ru` - Rack configuration file
- `spec/` - Test files

## Database Configuration

The application uses Mongoid as the MongoDB ODM. Configuration can be found in `config/mongoid.yml`.

### Using a Different Database

To use a different database (e.g., PostgreSQL, MySQL, SQLite):

1. Update your `Gemfile`:
```ruby
# Remove mongoid
# gem 'mongoid'

# Add ActiveRecord and database adapter
gem 'activerecord'
gem 'sinatra-activerecord'
gem 'pg'  # or 'mysql2', 'sqlite3'
```

2. Update `config/environment.rb` to use ActiveRecord instead of Mongoid

3. Run migrations:
```bash
bundle exec rake db:migrate
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
