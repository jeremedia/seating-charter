require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:cohorts).dependent(:destroy) }
    it { should have_many(:import_sessions).dependent(:destroy) }
    it { should have_many(:inference_feedbacks).dependent(:destroy) }
    it { should have_many(:cost_trackings).dependent(:destroy) }
    it { should have_many(:created_arrangements).class_name('SeatingArrangement').with_foreign_key('created_by_id').dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:password) }
    it { should validate_presence_of(:role) }
    it { should allow_value('instructor').for(:role) }
    it { should allow_value('admin').for(:role) }
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(instructor: 0, admin: 1) }
  end

  describe 'scopes' do
    let!(:instructor) { create(:user, :instructor) }
    let!(:admin) { create(:user, :admin) }

    describe '.instructors' do
      it 'returns only instructors' do
        expect(User.instructors).to include(instructor)
        expect(User.instructors).not_to include(admin)
      end
    end

    describe '.admins' do
      it 'returns only admins' do
        expect(User.admins).to include(admin)
        expect(User.admins).not_to include(instructor)
      end
    end
  end

  describe 'callbacks' do
    describe 'after_initialize' do
      context 'for new record' do
        it 'sets default role to instructor' do
          user = User.new
          expect(user.role).to eq('instructor')
        end
      end

      context 'for existing record' do
        it 'does not change existing role' do
          user = create(:user, :admin)
          user.reload
          expect(user.role).to eq('admin')
        end
      end
    end
  end

  describe 'class methods' do
    describe '.instructor_count' do
      it 'returns count of instructors' do
        create_list(:user, 3, :instructor)
        create_list(:user, 2, :admin)
        
        expect(User.instructor_count).to eq(3)
      end
    end

    describe '.can_add_instructor?' do
      before do
        stub_const('ENV', ENV.to_hash.merge('CHDS_MAX_INSTRUCTORS' => '3'))
      end

      context 'when under limit' do
        it 'returns true' do
          create_list(:user, 2, :instructor)
          expect(User.can_add_instructor?).to be true
        end
      end

      context 'when at limit' do
        it 'returns false' do
          create_list(:user, 3, :instructor)
          expect(User.can_add_instructor?).to be false
        end
      end

      context 'when over limit' do
        it 'returns false' do
          create_list(:user, 5, :instructor)
          expect(User.can_add_instructor?).to be false
        end
      end
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user) }

    describe '#instructor?' do
      context 'when user is instructor' do
        let(:user) { create(:user, :instructor) }
        
        it 'returns true' do
          expect(user.instructor?).to be true
        end
      end

      context 'when user is admin' do
        let(:user) { create(:user, :admin) }
        
        it 'returns false' do
          expect(user.instructor?).to be false
        end
      end
    end

    describe '#admin?' do
      context 'when user is admin' do
        let(:user) { create(:user, :admin) }
        
        it 'returns true' do
          expect(user.admin?).to be true
        end
      end

      context 'when user is instructor' do
        let(:user) { create(:user, :instructor) }
        
        it 'returns false' do
          expect(user.admin?).to be false
        end
      end
    end

    describe '#full_name' do
      context 'with first and last name' do
        let(:user) { create(:user, first_name: 'John', last_name: 'Doe') }
        
        it 'returns full name' do
          expect(user.full_name).to eq('John Doe')
        end
      end

      context 'with only first name' do
        let(:user) { create(:user, first_name: 'John', last_name: nil) }
        
        it 'returns first name' do
          expect(user.full_name).to eq('John')
        end
      end

      context 'with only last name' do
        let(:user) { create(:user, first_name: nil, last_name: 'Doe') }
        
        it 'returns last name' do
          expect(user.full_name).to eq('Doe')
        end
      end

      context 'without names' do
        let(:user) { create(:user, first_name: nil, last_name: nil, email: 'john@example.com') }
        
        it 'returns email' do
          expect(user.full_name).to eq('john@example.com')
        end
      end

      context 'with empty string names' do
        let(:user) { create(:user, first_name: '', last_name: '', email: 'john@example.com') }
        
        it 'returns email' do
          expect(user.full_name).to eq('john@example.com')
        end
      end
    end
  end

  describe 'Devise configuration' do
    it 'includes required devise modules' do
      devise_modules = User.devise_modules
      expect(devise_modules).to include(:database_authenticatable)
      expect(devise_modules).to include(:registerable)
      expect(devise_modules).to include(:recoverable)
      expect(devise_modules).to include(:rememberable)
      expect(devise_modules).to include(:validatable)
    end
  end
end