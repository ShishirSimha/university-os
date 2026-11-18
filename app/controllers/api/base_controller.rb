module Api
  class BaseController < ActionController::API
    private

    def render_error(message, status: :bad_request)
      render json: { status: Rack::Utils.status_code(status), message: message }, status: status
    end

    def authenticate_user!(allow_suspended: false)
      token = bearer_token
      if token.blank?
        render_error("Authorization token is required")
        return
      end

      payload = JsonWebToken.decode(token)
      user = User.find(payload.fetch("sub"))
      unless user.tenant_id.to_s == payload["tid"].to_s
        render_error("Invalid token")
        return
      end

      if !allow_suspended && user.tenant.suspended?
        render_error("Institution is suspended")
        return
      end

      @current_user = user
      @current_tenant = user.tenant
      @token_payload = payload
      Current.user = user
      Current.tenant = user.tenant
      Current.correlation_id = SecureRandom.uuid
    rescue JsonWebToken::RevokedError
      render_error("Token has been revoked")
    rescue JWT::ExpiredSignature
      render_error("Token has expired")
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      render_error("Invalid token")
    end

    def current_user
      @current_user
    end

    def current_tenant
      @current_tenant
    end

    def token_payload
      @token_payload
    end

    def bearer_token
      scheme, token = request.authorization.to_s.split(" ", 2)
      token if scheme&.casecmp("bearer")&.zero? && token.present?
    end
  end
end
