module Catalogue
  class Error < StandardError
    attr_reader :status

    def initialize(message, status: :bad_request)
      @status = status
      super(message)
    end
  end
end
