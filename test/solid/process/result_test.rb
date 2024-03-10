# frozen_string_literal: true

require "test_helper"

class Solid::Process::ResultTest < ActiveSupport::TestCase
  def setup
    ::User.delete_all
  end

  test "success" do
    input = {name: "\tJohn     Doe \n", email: "   JOHN.doe@email.com", password: "123123123"}

    result = assert_difference(
      -> { User.count } => 1
    ) do
      UserCreation.call(input)
    end

    assert_kind_of Solid::Result, result
    assert_kind_of Solid::Success, result

    assert result.success?(:user_created)
    assert_equal [:user], result.value.keys

    user = result.value.fetch(:user)

    assert_match(TestUtils::UUID_REGEX, user.uuid)
    assert_equal("John Doe", user.name)
    assert_equal("john.doe@email.com", user.email)

    assert BCrypt::Password.new(user.password_digest).is_password?(input[:password])
  end

  test "failure (invalid_input)" do
    input = {name: "     ", email: "John", password: "123123"}

    result = assert_no_difference(
      -> { User.count }
    ) do
      UserCreation.call(input)
    end

    assert_kind_of Solid::Result, result
    assert_kind_of Solid::Failure, result

    assert result.failure?(:invalid_input)
    assert_equal [:input], result.value.keys

    input = result.value[:input]

    assert_kind_of Solid::Input, input
    assert_instance_of UserCreation::Input, input

    input.errors.added? :name, :blank
    input.errors.added? :email, :invalid
  end

  test "failure (email_already_taken)" do
    input = {name: "John Doe", email: "john.doe@email.com", password: "123123123"}

    UserCreation.call(input)

    result = assert_no_difference(
      -> { User.count }
    ) do
      UserCreation.call(input)
    end

    assert result.failure?(:email_already_taken)
  end
end