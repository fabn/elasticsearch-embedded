describe Elasticsearch::Embedded do

  describe '.verbosity' do

    after { Logging.logger[subject].level = :info }

    it 'should allow numbers' do
      expect {
        subject.verbosity(2)
      }.to change { Logging.logger[subject].level }.from(Logging::LEVELS['info']).to(Logging::LEVELS['warn'])
    end

    it 'should allow level strings' do
      expect {
        subject.verbosity('warn')
      }.to change { Logging.logger[subject].level }.from(Logging::LEVELS['info']).to(Logging::LEVELS['warn'])
    end

    it 'should keep level to info on invalid levels' do
      expect {
        subject.verbosity('foo')
      }.to_not change { Logging.logger[subject].level }
    end

  end

  describe '.mute!' do

    after { Logging.logger[subject].appenders = Logging.appenders.stdout }

    it 'should remove all appenders' do
      expect {
        subject.mute!
      }.to change { Logging.logger[subject].appenders }.to([])
    end

  end

end