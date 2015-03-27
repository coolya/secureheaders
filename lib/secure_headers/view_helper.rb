module SecureHeaders
  class UnexpectedHashedScriptException < StandardError

  end

  module ViewHelpers
    include SecureHeaders::HashHelper
    SECURE_HEADERS_RAKE_TASK = "rake secure_headers:generate_hashes"

    def nonced_style_tag(content = nil, options = {}, &block)
      nonced_tag(content, options, :style, block)
    end

    def nonced_javascript_tag(content = nil, options = {}, &block)
      nonced_tag(content, options, :script, block)
    end

    def hashed_javascript_tag(raise_error_on_unrecognized_hash = false, options = {}, &block)
      content = capture(&block)

      if ['development', 'test'].include?(ENV["RAILS_ENV"])
        hash_value = hash_source(content)
        file_path = File.join('app', 'views', self.instance_variable_get(:@virtual_path) + '.html.erb')
        script_hashes = controller.instance_variable_get(:@script_hashes)[file_path]
        unless script_hashes && script_hashes.include?(hash_value)
          message = unexpected_hash_error_message(file_path, hash_value, content)
          if raise_error_on_unrecognized_hash
            raise UnexpectedHashedScriptException.new(message)
          else
            puts message
            request.env[HASHES_ENV_KEY] = (request.env[HASHES_ENV_KEY] || []) << hash_value
          end
        end
      end

      javascript_tag content, options
    end

    private

    def nonced_tag(content, options, type, block)
      content = if block
        # when using a block, the first argument will contain the options value
        options = content
        capture(&block)
      else
        content.html_safe # :'(
      end

      options ||= {}
      options.merge!(:nonce => @content_security_policy_nonce)

      content_tag type, content, options
    end

    def unexpected_hash_error_message(file_path, hash_value, content)
      <<-EOF
\n\n*** WARNING: Unrecognized hash in #{file_path}!!! Value: #{hash_value} ***
<script>#{content}</script>
*** This is fine in dev/test, but will raise exceptions in production. ***
*** Run #{SECURE_HEADERS_RAKE_TASK} or add the following to config/script_hashes.yml:***
#{file_path}:
- #{hash_value}\n\n
      EOF
    end
  end
end

module ActionView #:nodoc:
  class Base #:nodoc:
    include SecureHeaders::ViewHelpers
  end
end
