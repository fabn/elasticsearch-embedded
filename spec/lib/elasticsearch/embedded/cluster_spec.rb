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

end