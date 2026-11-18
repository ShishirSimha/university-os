require "test_helper"

class Api::Auth::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @institution = create_institution
    @user = create_auth_user(tenant: @institution)
  end

  test "resets the password and returns the user" do
    post "/api/auth/password/reset", params: { emai: " Test@Test.com ", password: "new password", institutionCode: "abc" }, as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal 200, body["status"]
    assert_equal "User password reset successfully", body["message"]
    assert_equal "test@test.com", body.dig("data", "email")
    assert_equal "Test Name", body.dig("data", "name")
    assert_equal "user", body.dig("data", "accountType")
    assert_nil body.dig("data", "password")
    assert_nil body.dig("data", "password_digest")
    assert_nil body.dig("data", "token")

    @user.reload
    assert @user.authenticate("new password")
    assert_not @user.authenticate("password")
  end

  test "accepts the email key" do
    post "/api/auth/password/reset", params: { email: "test@test.com", password: "new password", institution_code: "ABC" }, as: :json

    assert_response :ok
    assert @user.reload.authenticate("new password")
  end

  test "returns 400 when the email is missing or unknown" do
    post "/api/auth/password/reset", params: { password: "new password" }, as: :json

    assert_response :bad_request
    assert_equal 400, response.parsed_body["status"]
    assert_equal "Email can't be blank", response.parsed_body["message"]

    post "/api/auth/password/reset", params: { email: "missing@test.com", password: "new password", institutionCode: "ABC" }, as: :json

    assert_response :bad_request
    assert_equal "Email not found", response.parsed_body["message"]
    assert @user.reload.authenticate("password")
  end

  test "returns 400 when the new password is blank or too short" do
    post "/api/auth/password/reset", params: { email: "test@test.com", password: "" }, as: :json

    assert_response :bad_request
    assert_equal "Password can't be blank", response.parsed_body["message"]

    post "/api/auth/password/reset", params: { email: "test@test.com", password: "short", institutionCode: "ABC" }, as: :json

    assert_response :bad_request
    assert_includes response.parsed_body["message"], "Password is too short"
    assert @user.reload.authenticate("password")
  end

  test "resets only the user in the requested institution" do
    other_institution = create_institution(code: "XYZ", name: "XYZ University")
    other_user = create_auth_user(tenant: other_institution, email: "test@test.com", phone_number: "8000000000")

    post "/api/auth/password/reset", params: {
      email: "test@test.com",
      password: "new password",
      institutionCode: "XYZ"
    }, as: :json

    assert_response :ok
    assert other_user.reload.authenticate("new password")
    assert @user.reload.authenticate("password")
  end

  test "returns 400 when the institution is missing or suspended" do
    post "/api/auth/password/reset", params: { email: "test@test.com", password: "new password" }, as: :json

    assert_response :bad_request
    assert_equal "Institution code can't be blank", response.parsed_body["message"]

    @institution.update!(status: "suspended")
    post "/api/auth/password/reset", params: { email: "test@test.com", password: "new password", institutionCode: "ABC" }, as: :json

    assert_response :bad_request
    assert_equal "Institution is suspended", response.parsed_body["message"]
    assert @user.reload.authenticate("password")
  end
end
