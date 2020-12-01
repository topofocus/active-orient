module OrientSupport
    class DefaultFormatter < Logger::Formatter
        def self.call(severity, time, program_name, msg)
       "#{time.strftime("%d.%m.(%X)")}#{"%5s" % severity}->#{msg}"
        end
    end
end
