# Sanarei Middleware

A Sinatra-based middleware application generated using [Corneal](https://github.com/thebrianemory/corneal), a Sinatra app generator.

## Prerequisites

- Ruby 3.x
- MongoDB (default database)
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

## Setup

1. Clone the repository:
```bash
git clone <repository-url>
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
bundle exec tux
# or
bundle exec pry
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
