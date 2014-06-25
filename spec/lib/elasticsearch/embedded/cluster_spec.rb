describe Elasticsearch::Embedded::Cluster, :elasticsearch do

  describe '#clear_all_indices!' do

    it 'should delete all indices' do
      # Create a document and an index
      client.index index: 'test', type: 'test-type', id: 1, body: {title: 'Test'}
      expect {
        cluster.delete_all_indices!
      }.to change { client.indices.get_settings.count }.to(0)
    end

    it 'should delete all indices' do
      # Create a document and an index
      client.index index: 'test', type: 'test-type', id: 1, body: {title: 'Test'}
      client.index index: 'test2', type: 'test-type', id: 1, body: {title: 'Test'}
      expect {
        cluster.delete_index! 'test'
      }.to change { client.indices.get_settings.keys }.to(['test2'])
    end

  end

  describe '#pids' do

    it 'should return a list running instances pids' do
      puts cluster.pids
      expect(cluster.pids).to_not be_empty
    end

    it 'should return an empty array on errors' do
      not_started = Elasticsearch::Embedded::Cluster.new
      not_started.port = 50000 # Nobody should listen on this port
      expect(not_started.pids).to eq([])
    end

  end

  describe 'Cluster persistency' do

    let(:persistent_cluster) { Elasticsearch::Embedded::Cluster.new }
    let(:port) { cluster.port + 10 }
    let(:client) { Elasticsearch::Client.new host: "localhost:#{port}" }

    before do
      persistent_cluster.persistent = true
      persistent_cluster.cluster_name = 'persistent_cluster'
      persistent_cluster.port = port
    end

    after do
      # Ensure additional cluster is stopped when test is finished
      persistent_cluster.stop if persistent_cluster.running?
    end

    it 'should persist data across restarts' do
      persistent_cluster.start
      client.indices.create index: 'persistent', body: {
          settings: {
              index: {
                  number_of_shards: 1,
                  number_of_replicas: 0
              },
          }
      }
      client.index index: 'persistent', type: 'test-type', id: 1, body: {title: 'Test'}, refresh: true
      expect {
        persistent_cluster.stop
        persistent_cluster.start
      }.to_not change { client.indices.get_settings.count }
    end

  end

end