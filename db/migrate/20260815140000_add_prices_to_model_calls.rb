class AddPricesToModelCalls < ActiveRecord::Migration[8.1]
  # The rate this call was billed at, written down when the call is made.
  #
  # Cost used to be derived at read time from a hardcoded table, so editing one
  # number silently re-priced every call ever made: a run that cost four
  # dollars in August would show something else in September because somebody
  # corrected a rate. A price is a fact about the moment of the request, and it
  # belongs on the request.
  #
  # Rates rather than a total, so a change to the formula -- cache writes are
  # not billed today and should be -- can be applied to history instead of
  # being frozen out of it.
  #
  # Dollars per million tokens, matching how both providers publish. Six
  # decimal places carries the cheapest rate in the catalogue, $0.02 for a
  # cached read on gpt-5.6-luna, with room underneath.
  # Added one at a time rather than in a bulk change_table: strong_migrations
  # cannot see inside the block, and each of these on its own is a nullable
  # column, which it can check and pass.
  def change
    add_column :model_calls, :input_price, :decimal, precision: 12, scale: 6
    add_column :model_calls, :output_price, :decimal, precision: 12, scale: 6
    add_column :model_calls, :cache_read_price, :decimal, precision: 12, scale: 6
    add_column :model_calls, :cache_write_price, :decimal, precision: 12, scale: 6
  end
end
