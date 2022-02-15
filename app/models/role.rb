# frozen_string_literal: true

# Class modeling Roles within the application
class Role < ApplicationRecord
  before_update :readonly!
  has_and_belongs_to_many :users # # rubocop:disable Rails/HasAndBelongsToMany
  validates :name, uniqueness: true

  def readonly?
    !new_record? && name_was == 'admin'
  end
end
