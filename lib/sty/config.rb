require 'psych'

class Config



  def self.yaml(file)
    Psych.load_file("#{file}.yaml")
  end

end