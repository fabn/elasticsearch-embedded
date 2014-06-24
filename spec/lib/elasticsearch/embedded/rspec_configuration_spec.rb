describe Elasticsearch::Embedded::RSpec do

  describe 'RSpec configuration' do

    let(:stub_config) { double(:rspec_configuration).as_null_object }
    let(:filters) { [:elasticsearch, :search] }
    let(:cluster) { double(:cluster).as_null_object }

    before :each do
      allow(::RSpec).to receive(:configure).and_yield(stub_config)
    end

    describe '.configure_with' do

      before :each do
        allow(Elasticsearch::Embedded::RSpec::ElasticSearchHelpers).to receive(:memoized_cluster).and_return(cluster)
      end

      it 'should include helpers module into RSpec configuration' do
        expect(stub_config).to receive(:include).with(Elasticsearch::Embedded::RSpec::ElasticSearchHelpers, *filters)
        subject.configure_with(*filters)
      end

      it 'should configure before hooks' do
        expect(stub_config).to receive(:before).with(:each, *filters).and_yield
        subject.configure_with(*filters)
        expect(cluster).to have_received(:ensure_started!)
        expect(cluster).to have_received(:delete_all_indices!)
      end

      it 'should configure after suite hook' do
        expect(stub_config).to receive(:after).with(:suite).and_yield
        subject.configure_with(*filters)
        expect(cluster).to have_received(:stop)
      end

    end

    # This version is intended to be used with default configuration, i.e. without filters
    describe '.configure' do

      it 'should use :elastisearch filter only' do
        subject.configure
        expect(stub_config).to have_received(:include).with(Elasticsearch::Embedded::RSpec::ElasticSearchHelpers, :elasticsearch)
      end

    end

  end

end