# Sample code for blog post:
# https://blog.arkency.com/rename-stream-in-rails-event-store-with-zero-downtime/

# how fast events will be processed
TIME_UNIT = 10.0
# how much time wait before start catchup process
WAIT_TIME = 0.5

require 'ruby_event_store'

event_store = RubyEventStore::Client.new(
  repository: RubyEventStore::InMemoryRepository.new,
)

class StreamSwitch
  def initialize(event_store, source, target, lock: Mutex.new)
    @event_store = event_store
    @current = source
    @source = source
    @target = target
    @lock = lock
  end

  def publish(event)
    @lock.synchronize do
      @event_store.publish(event, stream_name: @current)
    end
  end

  def catchup(processed)
    @lock.synchronize do
      scope = @event_store.read.stream(@source).limit(5)
      scope = scope.from(processed) if processed
      events = scope.to_a
      change if events.empty?
      events
    end
  end

  def link(event)
    @event_store.link(event.event_id, stream_name: @target)
  end

  def to_s
    @current
  end

  private
  def change
    @current = @target
  end
end

FooEvent = Class.new(RubyEventStore::Event)
stream = StreamSwitch.new(event_store, "source", "target")

def publish(stream)
  index = 0
  while(true) do
    stream.publish(FooEvent.new(data: {index: index}))
    puts "#{index} published to stream: #{stream}"
    sleep(Random.rand(1.1) / TIME_UNIT)
    index += 1
  end
end


def catchup(stream)
  processed = nil
  while(true)
    events = stream.catchup(processed)
    break if events.empty?
    events.each do |event|
      stream.link(event)
      puts "#{event.data[:index]} linked to stream: target"
    end
    processed = events.last.event_id
    sleep(Random.rand(1) / TIME_UNIT)
  end
end


publish = Thread.new {publish(stream)}
sleep(WAIT_TIME)
puts "Starting catchup thread"
catchup = Thread.new {catchup(stream)}


catchup.join
puts "Catchup thread done"
sleep(WAIT_TIME)
publish.exit
puts "Publish thread done"

puts "Source stream:"
puts (source_events = event_store.read.stream("source").map{|x| x.data[:index]}).inspect
puts "Target stream:"
puts (target_events = event_store.read.stream("target").map{|x| x.data[:index]}).inspect

raise "FAIL"  unless target_events[0, source_events.size] == source_events
puts "DONE - now remove source stream"
