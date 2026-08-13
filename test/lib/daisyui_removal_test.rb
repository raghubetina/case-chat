require "test_helper"
require "json"

class DaisyuiRemovalTest < ActiveSupport::TestCase
  DAISYUI_CLASSES = %w[
    alert-error alert-info alert-warning bg-base-100 bg-base-200 border-base-300
    btn btn-circle btn-error btn-ghost btn-outline btn-primary btn-sm btn-xs
    card hero hero-content input input-bordered join join-item label link link-hover
    menu menu-horizontal navbar navbar-center navbar-end navbar-start rounded-box
    select select-bordered swap swap-off swap-on swap-rotate table text-base-content/60
    text-base-content/70 text-error text-primary theme-controller toast toast-center toast-top
  ].to_set.freeze

  test "removes the DaisyUI package and Tailwind plugin" do
    package = JSON.parse(Rails.root.join("package.json").read)
    dependencies = package.fetch("dependencies", {}).merge(package.fetch("devDependencies", {}))

    refute dependencies.key?("daisyui")
    refute_includes Rails.root.join("app/assets/stylesheets/application.tailwind.css").read.downcase, "daisyui"
  end

  test "removes DaisyUI classes from views" do
    used_classes = Rails.root.glob("app/views/**/*.erb").flat_map do |path|
      path.read.scan(/class(?:=|:)\s*["']([^"']+)["']/).flatten.flat_map(&:split)
    end

    assert_empty used_classes.to_set & DAISYUI_CLASSES
  end
end
