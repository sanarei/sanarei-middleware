# frozen_string_literal: true

module Sanarei
  # Converts an internal CON/END message into the mobile app's response envelope.
  class UssdResponse
    class << self
      def build(response)
        close_session = response.to_s.start_with?('END')
        message = response.to_s.sub(/\A(?:END|CON)\s+/, '')

        {
          shouldClose: close_session,
          ussdMenu: message,
          responseMessage: message,
          responseExitCode: 200
        }
      end
    end
  end
end
