describe user('ubuntu'), :skip do
	it { should exist }
end

describe port(22), :skip do
  it { should be_listening }
end
