require 'pry'
data_to_pull = {
	"5a3400fa942c6d289e38e0ca" => "2017-12-15",
	"587930526c5d1c5968000152" => "2017-09-12",
	"59f9f510942c6d5be82d813f" => "2017-11-01",
	"59fb34b6942c6d5bfd2cae13" => "2017-11-02",
	"59fb34e4942c6d5bfd2cb78c" => "2017-11-02",
	"59fb350f942c6d5bfd2cbb01" => "2017-11-02",
	"59fb353d942c6d5bfd2cbd47" => "2017-11-02",
	"59fb3581942c6d5bfd2cbeee" => "2017-11-02",
	"59fb35a7942c6d5bfd2cd72b" => "2017-11-02",
	"59fb35d4942c6d5bfd2cd841" => "2017-11-02",
	"59fb35fa942c6d5bfd2cd956" => "2017-11-02",
	"59fb478d942c6d5bfd2cdda2" => "2017-11-02",
	"59fb47c3942c6d5bfd2ce3c0" => "2017-11-02",
	"59fb47f1942c6d5bfd2cef99" => "2017-11-02",
	"59fb4815942c6d5bfd2cf136" => "2017-11-02",
	"59fb4837942c6d5bfd2cf3be" => "2017-11-02",
	"59fb4857942c6d5bfd2cf4ff" => "2017-11-02",
	"59fb487f942c6d5bfd2cf940" => "2017-11-02",
	"5a0c5fa2942c6d046af15b53" => "2017-11-15",
	"5a0dae67942c6d742399f3f0" => "2017-11-16",
	"5a149b1c942c6d42529aa8f9" => "2017-11-21",
	"5a149f5c942c6d42529aaa85" => "2017-11-21",
	"5a343031942c6d5240d4ae99" => "2017-12-15",
	"5a38349b942c6d7fc9cbf576" => "2017-12-18",
	"5a03601d942c6d2d1ff5fbea" => "2017-11-08",
	"5981066a942c6d20a8001cb7" => "2017-08-01",
	"597761c0942c6d40350086e8" => "2017-07-25",
	"59944fe0942c6d08fb000310" => "2017-08-16",
	"59ee1c33942c6d2fff001575" => "2017-10-23",
	"5a14a2c9942c6d47c479f846" => "2017-11-21",
	"5a343585942c6d54c7e41a11" => "2017-12-15"
}

def use_bonnie_alpha_dev
  system("sed -i -e 's/bonnie_alpha$/bonnie_alpha_dev/g' ~/git/bonnie/config/mongoid.yml;")
end

def use_bonnie_alpha
  system("sed -i -e 's/bonnie_alpha_dev$/bonnie_alpha/g' ~/git/bonnie/config/mongoid.yml;")
end

def update_alpha_dev (date)
  system("ruby ~/git/server-scripts/update_alpha_dev_db_date.rb #{date}")
end

def get_vs_oid_version_objects(measure_id)
  system("rake bonnie:measures:get_value_set_oid_version_objects MEASURE_ID=#{measure_id}")
end

def get_old_value_set_codes
  system("rake bonnie:measures:get_old_value_set_codes")
end

def determine_value_set_code_differences
  system("rake bonnie:measures:determine_value_set_code_differences")
end

use_bonnie_alpha_dev

data_to_pull.each do |measure_id, date| 
  update_alpha_dev(date)
  get_vs_oid_version_objects(measure_id)
end

use_bonnie_alpha

determine_value_set_code_differences()
