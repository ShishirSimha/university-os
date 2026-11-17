module JsonWebToken
  ALGORITHM = "HS256"
  EXPIRY = 30.minutes

  class << self
    def encode(user_id, expires_at: EXPIRY.from_now)
      payload = { sub: user_id, exp: expires_at.to_i }
      JWT.encode(payload, secret, ALGORITHM)
    end

    def decode(token)
      JWT.decode(token, secret, true, { algorithm: ALGORITHM }).first
    end

    private

    def secret
      Rails.application.secret_key_base
    end
  end
end
