require 'rails_event_store'
require 'aggregate_root'
require 'arkency/command_bus'

Rails.configuration.to_prepare do
  events_class_remapping = {}

  Rails.configuration.event_repository =
    RailsEventStoreActiveRecord::EventRepository.new(serializer: JSON)
  Rails.configuration.event_store = RailsEventStore::Client.new(
    repository: Rails.configuration.event_repository,
    mapper: RubyEventStore::Mappers::Default.new(
      events_class_remapping: events_class_remapping
    ),
    dispatcher: RubyEventStore::ComposedDispatcher.new(
      RubyEventStore::ImmediateAsyncDispatcher.new(scheduler: RailsEventStore::ActiveJobScheduler.new(serializer: JSON)),
      RubyEventStore::Dispatcher.new),
  )
  Rails.configuration.command_bus = Arkency::CommandBus.new

  # Subscribe event handlers below
  # Rails.configuration.event_store.tap do |store|
  #   store.subscribe(InvoiceReadModel.new, to: [InvoicePrinted])
  #   store.subscribe(->(event) { SendOrderConfirmation.new.call(event) }, to: [OrderSubmitted])
  #   store.subscribe_to_all_events(->(event) { Rails.logger.info(event.type) })
  # end

  # Register command handlers below
  # Rails.configuration.command_bus.tap do |bus|
  #   bus.register(PrintInvoice, Invoicing::OnPrint.new)
  #   bus.register(SubmitOrder,  ->(cmd) { Orders::OnSubmitOrder.new.call(cmd) })
  # end

  Orders.setup(Rails.configuration)
  Payments.setup(Rails.configuration)
  Shipping.setup(Rails.configuration)
end
