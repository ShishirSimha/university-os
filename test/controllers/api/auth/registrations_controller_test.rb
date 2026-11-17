require "test_helper"

class Api::Auth::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @payload = {
      email: "test@test.com",
      password: "password",
      name: "Test Name",
      accountType: "user",
      country: "Nigeria",
      countryCode: "+123",
      state: "Rivers",
      address: "No. 6 Prince Okey",
      phoneNumber: "8124566736"
    }
  end

  test "registers a user and returns a token" do
    assert_difference -> { User.count }, 1 do
      post "/api/auth/register", params: @payload, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 201, body["status"]
    assert_equal "User registered successfully", body["message"]

    user_json = body.dig("data", "user")
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

    user = User.find(user_json["id"])
    assert user.authenticate("password")

    payload = JsonWebToken.decode(body.dig("data", "token"))
    assert_equal user.id, payload.fetch("sub")
    assert_in_delta 30.minutes.from_now.to_i, payload.fetch("exp"), 5
  end

  test "accepts an admin account type and snake_case keys" do
    post "/api/auth/register", params: {
      email: "admin@test.com",
      password: "password",
      name: "Admin User",
      account_type: "Admin",
      country: "Nigeria",
      country_code: "+234",
      state: "Lagos",
      address: "1 Admin Road",
      phone_number: "8012345678"
    }, as: :json

    assert_response :created
    assert_equal "admin", response.parsed_body.dig("data", "user", "accountType")
    assert_equal "+234", response.parsed_body.dig("data", "user", "countryCode")
  end

  test "returns 400 when the email is already registered" do
    post "/api/auth/register", params: @payload, as: :json
    assert_response :created

    assert_no_difference -> { User.count } do
      post "/api/auth/register", params: @payload.merge(name: "Someone Else"), as: :json
    end

    assert_response :bad_request
    body = response.parsed_body
    assert_equal 400, body["status"]
    assert_includes body["message"], "Email has already been taken"
    assert_nil body["data"]
  end

  test "returns 400 when required fields are missing or invalid" do
    post "/api/auth/register", params: { email: "not-an-email", password: "short", accountType: "student" }, as: :json

    assert_response :bad_request
    body = response.parsed_body
    assert_equal 400, body["status"]
    assert_includes body["message"], "Email is invalid"
    assert_includes body["message"], "Password is too short"
    assert_includes body["message"], "Account type must be user or admin"
    assert_includes body["message"], "Name can't be blank"
  end
end
