module BitwardenRuby
  module Routing
    module Icons
      def self.registered(app)
        app.namespace ICONS_URL do
          get "/:domain/icon.png" do
            # TODO: do this service ourselves

            redirect "http://#{params[:domain]}/favicon.ico"
          end
        end
      end
    end
  end
end