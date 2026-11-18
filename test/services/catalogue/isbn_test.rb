require "test_helper"

class Catalogue::IsbnTest < ActiveSupport::TestCase
  test "normalizes and validates isbn 10 and isbn 13" do
    assert_equal "9780132350884", Catalogue::Isbn.normalize("978-0-13-235088-4")
    assert Catalogue::Isbn.valid_isbn13?("978-0-13-235088-4")
    assert Catalogue::Isbn.valid_isbn13?("9780132350891")
    assert_not Catalogue::Isbn.valid_isbn13?("9780132350885")
    assert Catalogue::Isbn.valid_isbn10?("0132350882")
    assert_not Catalogue::Isbn.valid_isbn10?("0132350883")
  end
end
