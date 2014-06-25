# Elasticsearch::Embedded

[![Gem Version](https://badge.fury.io/rb/elasticsearch-embedded.png)](http://badge.fury.io/rb/elasticsearch-embedded) [![Build Status](https://travis-ci.org/fabn/elasticsearch-embedded.svg?branch=master)](https://travis-ci.org/fabn/elasticsearch-embedded) [![Coverage Status](https://coveralls.io/repos/fabn/elasticsearch-embedded/badge.png)](https://coveralls.io/r/fabn/elasticsearch-embedded)

This gem allows to download and execute elasticsearch (single node or local cluster) within a local folder.

It also provides some utilities for usage in RSpec integration tests.

## Installation

Add this line to your application's Gemfile:

    gem 'elasticsearch-embedded'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install elasticsearch-embedded

## Usage

### Standalone mode

After gem installation you can run `embedded-elasticsearch` executable, it accepts some options for cluster configuration

```
$ embedded-elasticsearch -h
Usage: embedded-elasticsearch [options]
    -w, --working-dir=WORKING_DIR    Elasticsearch working directory (default: `Dir.tmpdir` or `Rails.root.join("tmp")` within rails applications)
    -p, --port=PORT                  Port on which to run elasticsearch (default: 9250)
    -c, --cluster-name=NAME          Cluster name (default: elasticsearch_test)
    -n, --nodes=NODES                Number of nodes started in the cluster (default: 1)
        --timeout=TIMEOUT            Timeout when starting the cluster (default: 30)
    -l, --log-level=LEVEL            Logger verbosity, numbers allowed (1..5) or level names (debug, info, warn, error, fatal)
    -q, --quiet                      Disable stdout logging
    -S, --show-es-output             Enable elasticsearch output in stdout
    -V VERSION                       Elasticsearch version to use (default 1.2.1)
    -P                               Configure cluster to persist data across restarts
    -h, --help                       Show this message
    -v, --version                    Show gem version
```

In order to start a single node cluster (with in memory indices) just run

```
$ embedded-elasticsearch -w tmp
Starting ES 1.2.1 cluster with working directory set to /Users/fabio/work/elasticsearch-embedded/tmp. Process pid is 57245
Downloading elasticsearch 1.2.1 |                                                    ᗧ| 100% (648 KB/sec) Time: 00:00:34
Starting 1 Elasticsearch nodes........
--------------------------------------------------------------------------------
Cluster:            elasticsearch_test
Status:             green
Nodes:              1
                    + node-1 | version: 1.2.1, pid: 57254, address: inet[/0:0:0:0:0:0:0:0:9250]

# Your cluster is running and listening to port 9250
```

### Usage with foreman

```
$ cat Procfile
elasticsearch: embedded-elasticsearch -w tmp
$ foreman start
14:53:51 elasticsearch.1 | started with pid 57524
14:53:51 elasticsearch.1 | Starting ES 1.2.1 cluster with working directory set to /Users/fabionapoleoni/Desktop/work/RubyMine/elasticsearch-embedded/tmp. Process pid is 57524
14:53:57 elasticsearch.1 | Starting 1 Elasticsearch nodes........
14:53:57 elasticsearch.1 | --------------------------------------------------------------------------------
14:53:57 elasticsearch.1 | Cluster:            elasticsearch_test
14:53:57 elasticsearch.1 | Status:             green
14:53:57 elasticsearch.1 | Nodes:              1
14:53:57 elasticsearch.1 |                     + node-1 | version: 1.2.1, pid: 57528, address: inet[/0:0:0:0:0:0:0:0:9250]
^CSIGINT received
14:54:02 system          | sending SIGTERM to all processes
14:54:02 elasticsearch.1 | exited with code 0%
```

### With RSpec

```ruby
# In spec/spec_helper.rb
require 'elasticsearch-embedded'
# Activate gem behavior with :elasticsearch tagged specs
Elasticsearch::Embedded::RSpec.configure
# Alternatively you could specify for which tags you want gem support
Elasticsearch::Embedded::RSpec.configure_with :search

# In tagged specs
describe Something, :elasticsearch do

  before(:each) do
    # all indices are deleted automatically at beginning of each spec
    expect(client.indices.get_settings).to be_empty
  end

  # If elastic search client is defined (i.e. with gem 'elasticsearch' or require 'elasticsearch')
  it 'should make elastic search client available' do
    expect(client).to be_an_instance_of(::Elasticsearch::Transport::Client)
    # Create a document into test cluster
    client.index index: 'test', type: 'test-type', id: 1, body: {title: 'Test'}
  end

  # Cluster object is also exposed in a helper
  it 'should make cluster object available' do
    expect(cluster).to be_an_instance_of(::Elasticsearch::Embedded::Cluster)
  end

  # If elastic search client is not defined client return an URI instance with base url for the cluster
  it 'should return cluster uri when elasticsearch is not defined' do
    ::Elasticsearch.send(:remove_const, :Client)
    expect(client).to be_an_instance_of(::URI::HTTP)
    expect(Net::HTTP.get(client)).to include('You Know, for Search')
  end

end

```

### With Test::Unit/minitest

Pull requests are welcome.

## Contributing

1. Fork it ( https://github.com/fabn/elasticsearch-embedded/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
