# frozen_string_literal: true

require './config/environment'

run ApplicationController
use Rack::CommonLogger
use Api::UssdController
