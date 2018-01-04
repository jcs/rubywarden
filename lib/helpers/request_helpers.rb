module BitwardenRuby
  module RequestHelpers
    def device_from_bearer
      if m = request.env["HTTP_AUTHORIZATION"].to_s.match(/^Bearer (.+)/)
        token = m[1]
        if (d = Device.find_by_access_token(token))
          if d.token_expires_at >= Time.now
            return d
          end
        end
      end

      nil
    end

    def need_params(*ps)
      ps.each do |p|
        if params[p].to_s.blank?
          yield(p)
        end
      end
    end

    def validation_error(msg)
      [ 400, {
        "ValidationErrors" => { "" => [
          msg,
        ]},
        "Object" => "error",
      }.to_json ]
    end
  end
end