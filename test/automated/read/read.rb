require_relative '../automated_init'

context "Read" do
  stream_name = Controls::Put.(instances: 2)

  batch = []

  Read.(stream_name, batch_size: 1) do |event_data|
    batch << event_data
  end

  test "Reads batches of events" do
    assert(batch.length == 2)
  end
end
