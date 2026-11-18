require "test_helper"

class Api::Auth::InstitutionsControllerTest < ActionDispatch::IntegrationTest
  test "creates an institution" do
    assert_difference -> { Tenant.count }, 1 do
      post "/api/auth/institutions", params: { name: " ABC University ", code: " abc " }, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 201, body["status"]
    assert_equal "Institution created successfully", body["message"]
    assert_equal "ABC University", body.dig("data", "name")
    assert_equal "ABC", body.dig("data", "code")
    assert_equal "active", body.dig("data", "status")
    assert_predicate body.dig("data", "id"), :present?
  end

  test "returns 400 when the code is already taken or invalid" do
    create_institution(code: "ABC")

    post "/api/auth/institutions", params: { name: "Other", code: "abc" }, as: :json

    assert_response :bad_request
    assert_equal 400, response.parsed_body["status"]
    assert_includes response.parsed_body["message"], "Institution code has already been taken"

    post "/api/auth/institutions", params: { name: "", code: "A" }, as: :json

    assert_response :bad_request
    assert_includes response.parsed_body["message"], "Name can't be blank"
    assert_includes response.parsed_body["message"], "Institution code must contain 2 to 50"
  end
end
