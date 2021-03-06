require_relative '../automated_init'

context "Get" do
  context "Batch Size" do
    stream_name = Controls::Put.(instances: 3)

    events = Get.(stream_name, batch_size: 2)

    number_of_events = events.length

    test "Number of events retrieved is the specified batch size" do
      assert(number_of_events == 2)
    end
  end
end
