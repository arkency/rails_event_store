RSpec.shared_examples :subscriptions do |subscriptions_class|
  Test1DomainEvent = Class.new(RubyEventStore::Event)
  Test2DomainEvent = Class.new(RubyEventStore::Event)
  Test3DomainEvent = Class.new(RubyEventStore::Event)

  class TestHandler
    def initialize
      @events = []
    end

    def call(event)
      @events << event
    end

    attr_reader :events
  end

  subject(:subscriptions) { subscriptions_class.new }

  it 'returns all subscribed handlers' do
    handler         = TestHandler.new
    another_handler = TestHandler.new
    global_handler  = TestHandler.new

    subscriptions.add_subscription(handler, ['Test1DomainEvent', 'Test3DomainEvent'])
    subscriptions.add_subscription(another_handler, ['Test2DomainEvent'])
    subscriptions.add_global_subscription(global_handler)

    expect(subscriptions.all_for('Test1DomainEvent')).to eq([handler, global_handler])
    expect(subscriptions.all_for('Test2DomainEvent')).to eq([another_handler, global_handler])
    expect(subscriptions.all_for('Test3DomainEvent')).to eq([handler, global_handler])
  end

  it 'returns subscribed thread handlers' do
    handler         = TestHandler.new
    another_handler = TestHandler.new
    global_handler  = TestHandler.new

    subscriptions.add_thread_subscription(handler, ['Test1DomainEvent', 'Test3DomainEvent'])
    subscriptions.add_thread_subscription(another_handler, ['Test2DomainEvent'])
    subscriptions.add_thread_global_subscription(global_handler)
    t = Thread.new do
      subscriptions.add_thread_subscription(handler, ['Test2DomainEvent'])
      subscriptions.add_thread_global_subscription(another_handler)
      expect(subscriptions.all_for('Test2DomainEvent')).to eq([another_handler, handler])
    end

    expect(subscriptions.all_for('Test1DomainEvent')).to eq([global_handler, handler])
    expect(subscriptions.all_for('Test2DomainEvent')).to eq([global_handler, another_handler])
    expect(subscriptions.all_for('Test3DomainEvent')).to eq([global_handler, handler])
    t.join
  end

  it 'returns lambda as an output of global subscribe methods' do
    handler   = TestHandler.new
    result = subscriptions.add_global_subscription(handler)
    expect(result).to respond_to(:call)
  end

  it 'returns lambda as an output of subscribe methods' do
    handler   = TestHandler.new
    result    = subscriptions.add_subscription(handler, [Test1DomainEvent, Test2DomainEvent])
    expect(result).to respond_to(:call)
  end

  it 'revokes global subscription' do
    handler   = TestHandler.new

    revoke    = subscriptions.add_global_subscription(handler)
    expect(subscriptions.all_for('Test1DomainEvent')).to eq([handler])
    expect(subscriptions.all_for('Test2DomainEvent')).to eq([handler])
    revoke.()
    expect(subscriptions.all_for('Test1DomainEvent')).to eq([])
    expect(subscriptions.all_for('Test2DomainEvent')).to eq([])
  end

  it 'revokes subscription' do
    handler   = TestHandler.new

    revoke    = subscriptions.add_subscription(handler, ['Test1DomainEvent', 'Test2DomainEvent'])
    expect(subscriptions.all_for('Test1DomainEvent')).to eq([handler])
    expect(subscriptions.all_for('Test2DomainEvent')).to eq([handler])
    revoke.()
    expect(subscriptions.all_for('Test1DomainEvent')).to eq([])
    expect(subscriptions.all_for('Test2DomainEvent')).to eq([])
  end

  it 'revokes thread global subscription' do
    handler   = TestHandler.new

    revoke    = subscriptions.add_thread_global_subscription(handler)
    expect(subscriptions.all_for('Test1DomainEvent')).to eq([handler])
    expect(subscriptions.all_for('Test2DomainEvent')).to eq([handler])
    revoke.()
    expect(subscriptions.all_for('Test1DomainEvent')).to eq([])
    expect(subscriptions.all_for('Test2DomainEvent')).to eq([])
  end

  it 'revokes thread subscription' do
    handler           = TestHandler.new

    revoke    = subscriptions.add_thread_subscription(handler, ['Test1DomainEvent', 'Test2DomainEvent'])
    expect(subscriptions.all_for('Test1DomainEvent')).to eq([handler])
    expect(subscriptions.all_for('Test2DomainEvent')).to eq([handler])
    revoke.()
    expect(subscriptions.all_for('Test1DomainEvent')).to eq([])
    expect(subscriptions.all_for('Test2DomainEvent')).to eq([])
  end

  it 'subscribes by type of event which is a String' do
    handler         = TestHandler.new
    subscriptions.add_subscription(handler, ["Test1DomainEvent"])
    subscriptions.add_thread_subscription(handler, ["Test1DomainEvent"])

    expect(subscriptions.all_for('Test1DomainEvent')).to eq([handler, handler])
  end

  it 'subscribes by type of event which is a class' do
    handler         = TestHandler.new
    subscriptions.add_subscription(handler, ['Test1DomainEvent'])
    subscriptions.add_thread_subscription(handler, ['Test1DomainEvent'])

    expect(subscriptions.all_for('Test1DomainEvent')).to eq([handler, handler])
  end
end
