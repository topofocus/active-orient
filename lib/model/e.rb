class E #< ActiveOrient::Model
      def self.naming_convention name=nil
          name.present? ? name.upcase : ref_name.upcase
      end
  end

