require 'hmac/signer'
require 'hmac/strategies/header'
require 'rack/builder'

context "header-based auth" do
  
  warden_struct = OpenStruct.new({
    :config => {
     :scope_defaults => {
       :default => {
         :hmac => {
           :secret => "secrit"
         }
       }
      } 
    }
  })
  
  warden_struct_custom_auth_header = OpenStruct.new({
    :config => {
     :scope_defaults => {
       :default => {
         :hmac => {
           :secret => Proc.new {|strategy|
             keys = {
               "KEY1" => 'secrit',
               "KEY2" => "foo"
             }
               
             access_key_id = strategy.parsed_auth_header["access_key_id"]
             keys[access_key_id]
           },
           :auth_header_format => '%{scheme} %{access_key_id} %{signature}'
         }
       }
      } 
    }
  })
  
  warden_struct_custom_auth_header_parse = OpenStruct.new({
    :config => {
     :scope_defaults => {
       :default => {
         :hmac => {
           :auth_scheme => 'HMAC:',
           :secret => Proc.new {|strategy|
             keys = {
               "KEY1" => 'secrit',
               "KEY2" => "foo"
             }
               
             access_key_id = strategy.parsed_auth_header["access_key_id"]
             keys[access_key_id]
           },
           :auth_header_format => '%{scheme} %{access_key_id} %{signature}',
           :auth_header_parse => /(?<scheme>[-_+.\w:]+) (?<access_key_id>[-_+.\w]+) (?<signature>[-_+.\w]+)/
           
         }
       }
      } 
    }
  })
  
  
  
  context "> without authorization header" do
    
    setup do
      env = {"warden" => warden_struct}
      strategy = Warden::Strategies::HMAC::Header.new(env_with_params('/', {}, env), :default)
    end
    
    denies(:valid?)
    
  end
  
  
  context "> with authorization header but invalid scheme name" do
    
    setup do
      env = {
        "warden" => warden_struct,
        "HTTP_Date" => "Mon, 20 Jun 2011 12:06:11 GMT",
        "HTTP_Authorization" => "Basic foo:bar"}
      strategy = Warden::Strategies::HMAC::Header.new(env_with_params('/', {}, env), :default)
    end
    
    denies(:valid?)
    
  end
  
  context "> with authorization header and valid scheme name" do
    
    setup do
      env = {
        "warden" => warden_struct,
        "HTTP_Date" => "Mon, 20 Jun 2011 12:06:11 GMT",
        "HTTP_Authorization" => "HMAC c2ce0f0885378f3e2e4024f505416c78abdd7a4b"}
      strategy = Warden::Strategies::HMAC::Header.new(env_with_params('/', {}, env), :default)
    end
    
    asserts(:valid?)
    denies(:timestamp_valid?)
    denies(:authenticate!).equals(:success)
  
    context "> with valid timestamp" do
      
      setup do
        Timecop.freeze Time.gm(2011, 7, 1, 20, 28, 55)
        
        env = {
          "warden" => warden_struct,
          "HTTP_Date" => Time.now.gmtime.strftime('%a, %e %b %Y %T GMT'),
          "HTTP_Authorization" => "HMAC c2ce0f0885378f3e2e4024f505416c78abdd7a4b"}
        strategy = Warden::Strategies::HMAC::Header.new(env_with_params('/', {}, env), :default)
      end
      
      teardown do
        Timecop.return
      end

      asserts(:valid?)
      asserts(:timestamp_valid?)
      denies(:authenticate!).equals(:success)
    end
    
    context "> with valid signature" do
      
      setup do
        Timecop.freeze Time.gm(2011, 7, 1, 20, 28, 55)
      
        env = {
          "warden" => warden_struct,
          "HTTP_Date" => Time.now.gmtime.strftime('%a, %e %b %Y %T GMT'),
          "HTTP_Authorization" => "HMAC a59456da1f61f86e96622e283780f58b7428c892"}
        strategy = Warden::Strategies::HMAC::Header.new(env_with_params('/', {}, env), :default)
      end
      
      teardown do
        Timecop.return
      end

      asserts(:valid?)
      asserts(:timestamp_valid?)
      asserts(:given_signature).equals("a59456da1f61f86e96622e283780f58b7428c892")
      asserts(:authenticate!).equals(:success)
    end
  
  end
  
  context "> using a custom auth header format" do
    
    context "> invalid key" do
      
      setup do
        Timecop.freeze Time.gm(2011, 7, 1, 20, 28, 55)
      
        env = {
          "warden" => warden_struct_custom_auth_header,
          "HTTP_Date" => Time.now.gmtime.strftime('%a, %e %b %Y %T GMT'),
          "HTTP_Authorization" => "HMAC KEY3 a59456da1f61f86e96622e283780f58b7428c892"}
        strategy = Warden::Strategies::HMAC::Header.new(env_with_params('/', {}, env), :default)
      end
      
      teardown do
        Timecop.return
      end

      asserts(:valid?)
      asserts(:timestamp_valid?)
      asserts(:given_signature).equals("a59456da1f61f86e96622e283780f58b7428c892")
      asserts("auth key id"){topic.parsed_auth_header["access_key_id"]}.equals("KEY3")
      denies(:authenticate!).equals(:success)
      
    end
    
    context "> invalid key" do
      
      setup do
        Timecop.freeze Time.gm(2011, 7, 1, 20, 28, 55)
      
        env = {
          "warden" => warden_struct_custom_auth_header,
          "HTTP_Date" => Time.now.gmtime.strftime('%a, %e %b %Y %T GMT'),
          "HTTP_Authorization" => "HMAC KEY3 a59456da1f61f86e96622e283780f58b7428c892"}
        strategy = Warden::Strategies::HMAC::Header.new(env_with_params('/', {}, env), :default)
      end
      
      teardown do
        Timecop.return
      end

      asserts(:valid?)
      asserts(:timestamp_valid?)
      asserts(:given_signature).equals("a59456da1f61f86e96622e283780f58b7428c892")
      asserts("auth key id"){topic.parsed_auth_header["access_key_id"]}.equals("KEY3")
      denies(:authenticate!).equals(:success)
      
    end
    
    context "> valid key and invalid signature" do
      setup do
        Timecop.freeze Time.gm(2011, 7, 1, 20, 28, 55)
      
        env = {
          "warden" => warden_struct_custom_auth_header,
          "HTTP_Date" => Time.now.gmtime.strftime('%a, %e %b %Y %T GMT'),
          "HTTP_Authorization" => "HMAC KEY2 a59456da1f61f86e96622e283780f58b7428c892"}
        strategy = Warden::Strategies::HMAC::Header.new(env_with_params('/', {}, env), :default)
      end
      
      teardown do
        Timecop.return
      end

      asserts(:valid?)
      asserts(:timestamp_valid?)
      asserts(:given_signature).equals("a59456da1f61f86e96622e283780f58b7428c892")
      asserts("auth key id"){topic.parsed_auth_header["access_key_id"]}.equals("KEY2")
      denies(:authenticate!).equals(:success)
    end
    
    context "> valid key and invalid signature and custom parser" do
      setup do
        Timecop.freeze Time.gm(2011, 7, 1, 20, 28, 55)
      
        env = {
          "warden" => warden_struct_custom_auth_header_parse,
          "HTTP_Date" => Time.now.gmtime.strftime('%a, %e %b %Y %T GMT'),
          "HTTP_Authorization" => "HMAC: KEY2 a59456da1f61f86e96622e283780f58b7428c892"}
        strategy = Warden::Strategies::HMAC::Header.new(env_with_params('/', {}, env), :default)
      end
      
      teardown do
        Timecop.return
      end

      asserts(:valid?)
      asserts(:timestamp_valid?)
      asserts(:scheme_valid?)
      asserts("scheme"){topic.parsed_auth_header["scheme"]}.equals("HMAC:")
      asserts(:given_signature).equals("a59456da1f61f86e96622e283780f58b7428c892")
      asserts("auth key id"){topic.parsed_auth_header["access_key_id"]}.equals("KEY2")
      denies(:authenticate!).equals(:success)
    end
    
  end
  
end
