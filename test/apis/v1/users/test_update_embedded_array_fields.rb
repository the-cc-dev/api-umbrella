require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestUpdateEmbeddedArrayFields < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_adds
    user = FactoryGirl.create(:api_user)
    assert_nil(user.roles)
    assert_nil(user.settings)

    attributes = user.serializable_hash
    attributes["roles"] = ["test-role1", "test-role2"]
    attributes["settings"] ||= {}
    attributes["settings"]["allowed_ips"] = ["127.0.0.1", "127.0.0.2"]
    attributes["settings"]["allowed_referers"] = ["http://google.com/", "http://yahoo.com/"]
    attributes["settings"]["rate_limit_mode"] = "custom"
    attributes["settings"]["rate_limits"] = [
      FactoryGirl.attributes_for(:api_rate_limit, :duration => 5000, :limit => 10),
      FactoryGirl.attributes_for(:api_rate_limit, :duration => 10000, :limit => 20),
    ]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(200, response)

    user.reload
    assert_equal(["test-role1", "test-role2"], user.roles)
    assert_equal(["127.0.0.1", "127.0.0.2"], user.settings.allowed_ips)
    assert_equal(["http://google.com/", "http://yahoo.com/"], user.settings.allowed_referers)
    assert_equal(2, user.settings.rate_limits.length)
    assert_equal(10, user.settings.rate_limits[0].limit)
    assert_equal(20, user.settings.rate_limits[1].limit)
  end

  def test_updates
    user = FactoryGirl.create(:api_user, {
      :roles => ["test-role1"],
      :settings => FactoryGirl.build(:api_setting, {
        :allowed_ips => ["127.0.0.1"],
        :allowed_referers => ["http://google.com/"],
        :rate_limit_mode => "custom",
        :rate_limits => [
          FactoryGirl.attributes_for(:api_rate_limit, :duration => 5000, :limit => 10),
          FactoryGirl.attributes_for(:api_rate_limit, :duration => 10000, :limit => 20),
        ],
      }),
    })
    assert_equal(["test-role1"], user.roles)
    assert_equal(["127.0.0.1"], user.settings.allowed_ips)
    assert_equal(["http://google.com/"], user.settings.allowed_referers)
    assert_equal(2, user.settings.rate_limits.length)
    assert_equal(10, user.settings.rate_limits[0].limit)
    assert_equal(20, user.settings.rate_limits[1].limit)

    attributes = user.serializable_hash
    attributes["roles"] = ["test-role5", "test-role4"]
    attributes["settings"]["allowed_ips"] = ["127.0.0.5", "127.0.0.4"]
    attributes["settings"]["allowed_referers"] = ["https://example.com", "https://bing.com/foo"]
    attributes["settings"]["rate_limits"][0]["limit"] = 50
    attributes["settings"]["rate_limits"][1]["limit"] = 75
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(200, response)

    user.reload
    assert_equal(["test-role5", "test-role4"], user.roles)
    assert_equal(["127.0.0.5", "127.0.0.4"], user.settings.allowed_ips)
    assert_equal(["https://example.com", "https://bing.com/foo"], user.settings.allowed_referers)
    assert_equal(2, user.settings.rate_limits.length)
    assert_equal(attributes["settings"]["rate_limits"][0]["id"], user.settings.rate_limits[0].id)
    assert_equal(5000, user.settings.rate_limits[0].duration)
    assert_equal(50, user.settings.rate_limits[0].limit)
    assert_equal(attributes["settings"]["rate_limits"][1]["id"], user.settings.rate_limits[1].id)
    assert_equal(10000, user.settings.rate_limits[1].duration)
    assert_equal(75, user.settings.rate_limits[1].limit)
  end

  def test_removes_single_value
    user = FactoryGirl.create(:api_user, {
      :roles => ["test-role1", "test-role2"],
      :settings => FactoryGirl.build(:api_setting, {
        :allowed_ips => ["127.0.0.1", "127.0.0.2"],
        :allowed_referers => ["http://google.com/", "http://yahoo.com/"],
        :rate_limit_mode => "custom",
        :rate_limits => [
          FactoryGirl.attributes_for(:api_rate_limit, :duration => 5000, :limit => 10),
          FactoryGirl.attributes_for(:api_rate_limit, :duration => 10000, :limit => 20),
        ],
      }),
    })
    assert_equal(["test-role1", "test-role2"], user.roles)
    assert_equal(["127.0.0.1", "127.0.0.2"], user.settings.allowed_ips)
    assert_equal(["http://google.com/", "http://yahoo.com/"], user.settings.allowed_referers)
    assert_equal(2, user.settings.rate_limits.length)
    assert_equal(10, user.settings.rate_limits[0].limit)
    assert_equal(20, user.settings.rate_limits[1].limit)

    attributes = user.serializable_hash
    attributes["roles"].shift
    attributes["settings"]["allowed_ips"].shift
    attributes["settings"]["allowed_referers"].shift
    attributes["settings"]["rate_limits"].shift
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(200, response)

    user.reload
    assert_equal(["test-role2"], user.roles)
    assert_equal(["127.0.0.2"], user.settings.allowed_ips)
    assert_equal(["http://yahoo.com/"], user.settings.allowed_referers)
    assert_equal(1, user.settings.rate_limits.length)
    assert_equal(attributes["settings"]["rate_limits"][0]["id"], user.settings.rate_limits[0].id)
    assert_equal(20, user.settings.rate_limits[0].limit)
  end

  [nil, []].each do |empty_value|
    empty_method_name =
      case(empty_value)
      when nil
        "null"
      when []
        "empty_array"
      end

    define_method("test_removes_#{empty_method_name}") do
      user = FactoryGirl.create(:api_user, {
        :roles => ["test-role1"],
        :settings => FactoryGirl.build(:api_setting, {
          :allowed_ips => ["127.0.0.1"],
          :allowed_referers => ["http://google.com/"],
          :rate_limit_mode => "custom",
          :rate_limits => [
            FactoryGirl.attributes_for(:api_rate_limit, :duration => 5000, :limit => 10),
            FactoryGirl.attributes_for(:api_rate_limit, :duration => 10000, :limit => 20),
          ],
        }),
      })
      assert_equal(["test-role1"], user.roles)
      assert_equal(["127.0.0.1"], user.settings.allowed_ips)
      assert_equal(["http://google.com/"], user.settings.allowed_referers)
      assert_equal(10, user.settings.rate_limits[0].limit)
      assert_equal(20, user.settings.rate_limits[1].limit)

      attributes = user.serializable_hash
      attributes["roles"] = empty_value
      attributes["settings"]["allowed_ips"] = empty_value
      attributes["settings"]["allowed_referers"] = empty_value
      attributes["settings"]["rate_limits"] = empty_value

      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:user => attributes),
      }))
      assert_response_code(200, response)

      user.reload
      # Setting to [] gets turned into nil by Rack:
      # http://guides.rubyonrails.org/v4.2/security.html#unsafe-query-generation
      # This should be fine, although for future upgrades, it looks like empty
      # array support is back in Rails 5:
      # http://guides.rubyonrails.org/v5.0/security.html#unsafe-query-generation
      assert_nil(user.roles)
      assert_nil(user.settings.allowed_ips)
      assert_nil(user.settings.allowed_referers)
      assert_equal([], user.settings.rate_limits)
    end
  end

  def test_keeps_not_present_keys
    user = FactoryGirl.create(:api_user, {
      :roles => ["test-role1"],
      :settings => FactoryGirl.build(:api_setting, {
        :allowed_ips => ["127.0.0.1"],
        :allowed_referers => ["http://google.com/"],
        :rate_limit_mode => "custom",
        :rate_limits => [
          FactoryGirl.attributes_for(:api_rate_limit, :duration => 5000, :limit => 10),
          FactoryGirl.attributes_for(:api_rate_limit, :duration => 10000, :limit => 20),
        ],
      }),
    })
    refute_equal("Updated", user.use_description)
    assert_equal(["test-role1"], user.roles)
    assert_equal(["127.0.0.1"], user.settings.allowed_ips)
    assert_equal(["http://google.com/"], user.settings.allowed_referers)
    assert_equal(10, user.settings.rate_limits[0].limit)
    assert_equal(20, user.settings.rate_limits[1].limit)

    attributes = user.serializable_hash
    attributes["use_description"] = "Updated"
    attributes.delete("roles")
    attributes["settings"].delete("allowed_ips")
    attributes["settings"].delete("allowed_referers")
    attributes["settings"].delete("rate_limits")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(200, response)

    user.reload
    assert_equal("Updated", user.use_description)
    assert_equal(["test-role1"], user.roles)
    assert_equal(["127.0.0.1"], user.settings.allowed_ips)
    assert_equal(["http://google.com/"], user.settings.allowed_referers)
    assert_equal(10, user.settings.rate_limits[0].limit)
    assert_equal(20, user.settings.rate_limits[1].limit)
  end
end
