require "test_helper"

class Api::Auth::LoginControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "test@test.com",
      password: "password",
      name: "Test Name",
      account_type: "user",
      country: "Nigeria",
      country_code: "+123",
      state: "Rivers",
      address: "No. 6 Prince Okey",
      phone_number: "8124566736"
    )
  end

  test "logs in with email and password and returns a token" do
    post "/api/auth/login", params: { emai: " Test@Test.com ", password: "password" }, as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal 200, body["status"]
    assert_equal "Login successfully", body["message"]

    user_json = body.dig("data", "user")
    assert_equal @user.id, user_json["id"]
    assert_equal "test@test.com", user_json["email"]
    assert_equal "Test Name", user_json["name"]
    assert_equal "user", user_json["accountType"]
    assert_equal "Nigeria", user_json["country"]
    assert_equal "+123", user_json["countryCode"]
    assert_equal "Rivers", user_json["state"]
    assert_equal "No. 6 Prince Okey", user_json["address"]
    assert_equal "8124566736", user_json["phoneNumber"]
    assert_nil user_json["password"]
    assert_nil user_json["password_digest"]

    payload = JsonWebToken.decode(body.dig("data", "token"))
    assert_equal @user.id, payload.fetch("sub")
    assert_predicate payload.fetch("jti"), :present?
    assert_in_delta 30.minutes.from_now.to_i, payload.fetch("exp"), 5
  end

  test "accepts the email key" do
    post "/api/auth/login", params: { email: "test@test.com", password: "password" }, as: :json

    assert_response :ok
    assert_equal "Login successfully", response.parsed_body["message"]
  end

  test "returns 400 when the password is wrong" do
    post "/api/auth/login", params: { email: "test@test.com", password: "wrong-password" }, as: :json

    assert_response :bad_request
    body = response.parsed_body
    assert_equal 400, body["status"]
    assert_equal "Invalid email or password", body["message"]
    assert_nil body["data"]
  end

  test "returns 400 when the email is unknown or missing" do
    post "/api/auth/login", params: { email: "missing@test.com", password: "password" }, as: :json

    assert_response :bad_request
    assert_equal "Invalid email or password", response.parsed_body["message"]

    post "/api/auth/login", params: { password: "password" }, as: :json

    assert_response :bad_request
    assert_equal "Invalid email or password", response.parsed_body["message"]
  end
end
