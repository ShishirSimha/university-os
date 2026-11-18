require "test_helper"

class Api::Auth::LoginControllerTest < ActionDispatch::IntegrationTest
  setup do
    @institution = create_institution
    @user = create_auth_user(tenant: @institution)
  end

  test "logs in with email and password and returns a token" do
    post "/api/auth/login", params: { emai: " Test@Test.com ", password: "password", institutionCode: "abc" }, as: :json

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
    assert_equal @institution.id, user_json.dig("institution", "id")
    assert_equal "ABC", user_json.dig("institution", "code")

    payload = JsonWebToken.decode(body.dig("data", "token"))
    assert_equal @user.id, payload.fetch("sub")
    assert_equal @institution.id, payload.fetch("tid")
    assert_predicate payload.fetch("jti"), :present?
    assert_in_delta 30.minutes.from_now.to_i, payload.fetch("exp"), 5
  end

  test "accepts the email key" do
    post "/api/auth/login", params: { email: "test@test.com", password: "password", institution_code: "ABC" }, as: :json

    assert_response :ok
    assert_equal "Login successfully", response.parsed_body["message"]
  end

  test "returns 400 when the password is wrong" do
    post "/api/auth/login", params: { email: "test@test.com", password: "wrong-password", institutionCode: "ABC" }, as: :json

    assert_response :bad_request
    body = response.parsed_body
    assert_equal 400, body["status"]
    assert_equal "Invalid email or password", body["message"]
    assert_nil body["data"]
  end

  test "returns 400 when the email is unknown or missing" do
    post "/api/auth/login", params: { email: "missing@test.com", password: "password", institutionCode: "ABC" }, as: :json

    assert_response :bad_request
    assert_equal "Invalid email or password", response.parsed_body["message"]

    post "/api/auth/login", params: { password: "password", institutionCode: "ABC" }, as: :json

    assert_response :bad_request
    assert_equal "Invalid email or password", response.parsed_body["message"]
  end

  test "does not authenticate a user against another institution" do
    create_institution(code: "XYZ", name: "XYZ University")

    post "/api/auth/login", params: { email: "test@test.com", password: "password", institutionCode: "XYZ" }, as: :json

    assert_response :bad_request
    assert_equal "Invalid email or password", response.parsed_body["message"]
  end

  test "returns 400 when the institution is missing, unknown, or suspended" do
    post "/api/auth/login", params: { email: "test@test.com", password: "password" }, as: :json

    assert_response :bad_request
    assert_equal "Institution code can't be blank", response.parsed_body["message"]

    post "/api/auth/login", params: { email: "test@test.com", password: "password", institutionCode: "NOPE" }, as: :json

    assert_response :bad_request
    assert_equal "Institution not found", response.parsed_body["message"]

    @institution.update!(status: "suspended")
    post "/api/auth/login", params: { email: "test@test.com", password: "password", institutionCode: "ABC" }, as: :json

    assert_response :bad_request
    assert_equal "Institution is suspended", response.parsed_body["message"]
  end
end
