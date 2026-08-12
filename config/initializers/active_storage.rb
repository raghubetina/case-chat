# strict_loading_by_default is a guardrail for *our* queries: it turns an
# accidental N+1 in app code into a failing test. Active Storage's own internals
# lazily load their associations by design — purging a blob walks
# blob.variant_records — so applying the guardrail to framework tables just
# breaks Rails rather than catching anything of ours.
ActiveSupport.on_load(:active_storage_record) do
  self.strict_loading_by_default = false
end
