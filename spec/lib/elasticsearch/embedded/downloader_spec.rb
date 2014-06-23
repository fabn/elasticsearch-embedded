describe Elasticsearch::Embedded::Downloader do

  describe 'configuration using env' do

    it 'should allow configuration through ENV' do
      ENV['ELASTICSEARCH_VERSION'] = '1.3.3'
      ENV['ELASTICSEARCH_DOWNLOAD_PATH'] = '/tmp'
      d = Elasticsearch::Embedded::Downloader.new
      expect(d.version).to eq '1.3.3'
      expect(d.path).to eq '/tmp'
    end

    after(:each) do
      ENV['ELASTICSEARCH_VERSION'] = nil
      ENV['ELASTICSEARCH_DOWNLOAD_PATH'] = nil
    end

  end

  describe 'configuration using options' do

    it 'should allow configuration using option arguments' do
      d = Elasticsearch::Embedded::Downloader.new(path: '/tmp', version: '1.3.3')
      expect(d.version).to eq '1.3.3'
      expect(d.path).to eq '/tmp'
    end

  end

  describe 'default configuration' do

    it 'should use default values' do
      d = Elasticsearch::Embedded::Downloader.new
      expect(d.version).to eq Elasticsearch::Embedded::Downloader::DEFAULT_VERSION
      expect(d.path).to eq Elasticsearch::Embedded::Downloader::TEMPORARY_PATH
    end

  end

  # Integration tests
  context 'with mocked filesystem' do

    # Stub filesystem calls
    include FakeFS::SpecHelpers

    let(:fake_archive) do
      directory = "/elasticsearch-#{subject.version}"
      archive = "/elasticsearch-#{subject.version}.zip"
      FileUtils.mkdir_p(directory)
      FileUtils.touch(File.join(directory, 'README.textile'))
      FileUtils.mkdir_p(File.join(directory, 'bin'))
      FileUtils.touch(File.join(directory, 'bin', 'elasticsearch'))
      # Creates a zip archive with empty files
      Zip::File.open(archive, Zip::File::CREATE) do |zipfile|
        # make root folder of zip archive
        zipfile.add(directory.sub('/', ''), directory)
        # Add all content
        Dir[File.join(directory, '**', '**')].each do |file|
          zipfile.add(file.sub('/', ''), file)
        end
      end
      # Return the built archive file name
      archive
    end

    # Realpath is needed because mockfs does not implement realpath
    let(:path) { File.realpath(Dir.tmpdir) }
    let(:zip_file) { File.join(path, "elasticsearch-#{subject.version}.zip") }
    let(:dist_folder) { File.join(path, "elasticsearch-#{subject.version}") }
    subject { Elasticsearch::Embedded::Downloader.new(path: path) }

    before do
      # This is needed on OS X where /tmp is a symlink otherwise the
      # openuri call will fail with Errno::ENOENT when trying to create a temporary file
      FileUtils.mkdir_p(Dir.tmpdir)
      # Ensure download path is present on the stubbed filesystem
      FileUtils.mkdir_p(path)
    end

    describe 'file download' do

      it 'should download file into configured path' do
        expect(File.exists?(zip_file)).to be_falsey
        # Stub only actual download of file
        expect(OpenURI).to receive(:open_uri).and_return(File.open(fake_archive))
        subject.perform
        expect(File.size(zip_file)).to be >= 0
      end

      it 'should not download file if already present' do
        FileUtils.touch(zip_file) # Simulate presence of downloaded version
        FileUtils.mkdir_p(dist_folder) # Simulate presence of extracted version
        expect { subject.perform }.to_not change { File.size(zip_file) }
      end

    end

    describe 'file extraction' do

      before do
        # create the zip archive as if it were downloaded
        expect(File.exists?(fake_archive)).to be_truthy
        FileUtils.cp fake_archive, zip_file
      end

      it 'should extract zip archive when into final folder' do
        expect {
          subject.perform
          # Fake archive contains 3 elements
        }.to change { Dir[File.join(dist_folder, '**', '**')].count }.to(3)
      end

      it 'should not extract zip archive when final folder is already present' do
        FileUtils.mkdir_p dist_folder
        expect { subject.perform }.to_not change { Dir[File.join(dist_folder, '**', '**')] }
      end

    end

  end

end