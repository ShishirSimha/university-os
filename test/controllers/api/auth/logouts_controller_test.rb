require "test_helper"

class Api::Auth::LogoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @institution = create_institution
    @user = create_auth_user(tenant: @institution)
  end

  test "logs out and revokes the bearer token" do
    post "/api/auth/login", params: { email: "test@test.com", password: "password", institutionCode: "ABC" }, as: :json
    token = response.parsed_body.dig("data", "token")
    payload = JsonWebToken.decode(token)

    assert_difference -> { RevokedToken.count }, 1 do
      post "/api/auth/logout", headers: { "Authorization" => "Bearer #{token}" }, as: :json
    end

    assert_response :ok
    body = response.parsed_body
    assert_equal 200, body["status"]
    assert_equal "User logged out successfully", body["message"]
    assert_equal "test@test.com", body.dig("data", "email")
    assert_equal "Test Name", body.dig("data", "name")
    assert_equal @user.id, body.dig("data", "id")
    assert_nil body.dig("data", "password")
    assert_nil body.dig("data", "password_digest")
    assert RevokedToken.revoked?(payload.fetch("jti"))

    assert_raises(JsonWebToken::RevokedError) { JsonWebToken.decode(token) }

    post "/api/auth/logout", headers: { "Authorization" => "Bearer #{token}" }, as: :json

    assert_response :bad_request
    assert_equal 400, response.parsed_body["status"]
    assert_equal "Token has been revoked", response.parsed_body["message"]
  end

  test "returns 400 when the token is missing, invalid, or expired" do
    post "/api/auth/logout", as: :json

    assert_response :bad_request
    assert_equal "Authorization token is required", response.parsed_body["message"]

    post "/api/auth/logout", headers: { "Authorization" => "Bearer not-a-token" }, as: :json

    assert_response :bad_request
    assert_equal "Invalid token", response.parsed_body["message"]

    expired = JsonWebToken.encode(@user.id, @user.tenant_id, expires_at: 1.minute.ago)
    post "/api/auth/logout", headers: { "Authorization" => "Bearer #{expired}" }, as: :json

    assert_response :bad_request
    assert_equal "Token has expired", response.parsed_body["message"]
  end

  test "rejects a token issued for another institution and still logs out a suspended institution" do
    other = create_institution(code: "XYZ", name: "XYZ University")
    mismatched = JsonWebToken.encode(@user.id, other.id)
    post "/api/auth/logout", headers: { "Authorization" => "Bearer #{mismatched}" }, as: :json

    assert_response :bad_request
    assert_equal "Invalid token", response.parsed_body["message"]
    assert_not RevokedToken.revoked?(JsonWebToken.decode(mismatched).fetch("jti"))

    token = JsonWebToken.encode(@user.id, @user.tenant_id)
    @institution.update!(status: "suspended")
    post "/api/auth/logout", headers: { "Authorization" => "Bearer #{token}" }, as: :json

    assert_response :ok
    assert_raises(JsonWebToken::RevokedError) { JsonWebToken.decode(token) }
  end
end
