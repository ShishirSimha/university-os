module JsonWebToken
  class RevokedError < JWT::DecodeError; end

  ALGORITHM = "HS256"
  EXPIRY = 30.minutes

  class << self
    def encode(user_id, expires_at: EXPIRY.from_now)
      payload = { sub: user_id, jti: SecureRandom.uuid, exp: expires_at.to_i }
      JWT.encode(payload, secret, ALGORITHM)
    end

    def decode(token)
      payload = verified_payload(token)
      raise RevokedError, "Token has been revoked" if RevokedToken.revoked?(payload["jti"])

      payload
    end

    def revoke(payload)
      jti = payload["jti"].to_s
      raise JWT::DecodeError, "Invalid token" if jti.blank?

      RevokedToken.create!(jti: jti, expires_at: Time.zone.at(payload.fetch("exp")))
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      raise RevokedError, "Token has been revoked"
    end

    private

    def verified_payload(token)
      JWT.decode(token, secret, true, { algorithm: ALGORITHM }).first
    end

    def secret
      Rails.application.secret_key_base
    end
  end
end
