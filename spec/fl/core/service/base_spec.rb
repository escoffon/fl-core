RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
end

class TestDatumOneController < ApplicationController
  def initialize(params)
    @my_params = params
  end

  def params()
    @my_params
  end
end

class TestDatumOneService < Fl::Core::Service::Base
  self.model_class = Fl::Core::TestDatumOne
end

module MyModule
  class DatumOneService < Fl::Core::Service::Base
    self.model_class = Fl::Core::TestDatumOne
  end
end

def _expect_no_permission(status)
  expect(status[:status]).to eql(Fl::Core::Service::FORBIDDEN)
  expect(status[:response_data]).to include(Fl::Core::Service::FORBIDDEN)
  expect(status[:response_data][Fl::Core::Service::FORBIDDEN]).to include(:_error)
  expect(status[:response_data][Fl::Core::Service::FORBIDDEN][:_error]).to include(:type, :message)
  expect(status[:response_data][Fl::Core::Service::FORBIDDEN][:_error][:type]).to eql('no_permission')
end

RSpec.describe Fl::Core::Service::Base do
  let(:a1) { create(:test_actor, name: 'a1') }
  let(:a2) { create(:test_actor, name: 'a2') }
  let(:a3) { create(:test_actor, name: 'a3') }
  let(:a4) { create(:test_actor, name: 'a4') }

  let(:d10) { create(:test_datum_one, owner: a1, title: 'd10') }
  let(:d11) { create(:test_datum_one, owner: a1, title: 'd11') }
  let(:d12) { create(:test_datum_one, owner: a1, title: 'd12') }
  let(:d13) { create(:test_datum_one, owner: a1, title: 'd3') }

  let(:g1) do
    [
      [ d10, [ [ a1, [ Fl::Core::Access::Permission::Edit::NAME ] ],
               [ a2, [ Fl::Core::Access::Permission::Read::NAME,
                       Fl::Core::Access::Permission::Delete::NAME ] ] ] ],
      [ d12, [ [ a1, [ Fl::Core::Access::Permission::Read::NAME ] ],
               [ a2, [ Fl::Core::Access::Permission::Read::NAME,
                       Fl::Core::Access::Permission::Write::NAME ] ] ] ]
    ]
  end

  describe '#localization_key' do
    it 'should convert to underscored names' do
      s1 = TestDatumOneService.new(nil)
      expect(s1.send(:localization_key, :key)).to eql('test_datum_one_service.key')
    end

    it 'should handle nested class declarations' do
      s2 = MyModule::DatumOneService.new(nil)
      expect(s2.send(:localization_key, :key)).to eql('my_module.datum_one_service.key')
    end
  end

  describe '#localized_message' do
    it 'should use the backstop catalog' do
      s1 = TestDatumOneService.new(nil)

      msg = s1.localized_message('forbidden', id: 'IDVALUE', action: 'OPVALUE')
      expect(msg).to include('IDVALUE')
      expect(msg).to include('OPVALUE')
    end

    it 'should use the class-specific catalog' do
      s1 = TestDatumOneService.new(nil)
      msg = s1.localized_message('not_found', id: 'IDVALUE')
      expect(msg).to eql('test_datum_one_service: not_found-IDVALUE-')

      s2 = MyModule::DatumOneService.new(nil)
      msg = s2.localized_message('forbidden', id: 'IDVALUE', action: 'OPVALUE')
      expect(msg).to eql('my_module.datum_one_service: forbidden-OPVALUE-IDVALUE-')
      msg = s2.localized_message('not_found', id: 'IDVALUE', action: 'OPVALUE')
      expect(msg).to eql('my_module.datum_one_service: not_found-IDVALUE-')
    end
  end

  describe '#get_and_check' do
    context 'with nil action' do
      it 'should find an existing object' do
        params = { id: d10.id }
        s1 = TestDatumOneService.new(a1, params)
        expect(s1.success?).to eql(true)
        
        obj = s1.get_and_check(nil)
        expect(s1.success?).to eql(true)
        expect(obj).to be_a(Fl::Core::TestDatumOne)
        expect(obj.fingerprint).to eql(d10.fingerprint)
      end

      it 'should find an existing object with custom id keys' do
        params = { obj_id: d10.id }
        s1 = TestDatumOneService.new(a1, params)
        expect(s1.success?).to eql(true)
        
        obj = s1.get_and_check(nil, [ :id, :obj_id ])
        expect(s1.success?).to eql(true)
        expect(obj).to be_a(Fl::Core::TestDatumOne)
        expect(obj.fingerprint).to eql(d10.fingerprint)
      end

      it 'should not find a nonexisting object' do
        params = { id: 0 }
        s1 = TestDatumOneService.new(a1, params)
        expect(s1.success?).to eql(true)
        
        obj = s1.get_and_check(nil)
        expect(s1.success?).to eql(false)
        expect(s1.status).to include(:status, :response_data)
        rd = s1.status[:response_data]
        expect(rd).to be_a(Hash)
        expect(rd).to include(:not_found)
        e = rd[:not_found]
        expect(e).to be_a(Hash)
        expect(e).to include(:_error)
        expect(e[:_error]).to include(:type, :message)
        expect(e[:_error][:message]).to include('not_found-id:0-')
      end

      it 'should not find a nonexisting object with custom id keys' do
        params = { obj_id: 0 }
        s1 = TestDatumOneService.new(a1, params)
        expect(s1.success?).to eql(true)
        
        obj = s1.get_and_check(nil, [ :id, :obj_id ])
        expect(s1.success?).to eql(false)
        expect(s1.status).to include(:status, :response_data)
        rd = s1.status[:response_data]
        expect(rd).to be_a(Hash)
        expect(rd).to include(:not_found)
        e = rd[:not_found]
        expect(e).to be_a(Hash)
        expect(e).to include(:_error)
        expect(e[:_error]).to include(:type, :message)
        expect(e[:_error][:message]).to include('not_found-id:,obj_id:0-')
      end

      it 'should use the controller params' do
        params = { id: d10.id }
        s1 = TestDatumOneService.new(a1, nil, TestDatumOneController.new(params))
        expect(s1.success?).to eql(true)

        obj = s1.get_and_check(nil)
        expect(s1.success?).to eql(true)
        expect(obj).to be_a(Fl::Core::TestDatumOne)
        expect(obj.fingerprint).to eql(d10.fingerprint)
      end
    end

    context 'with action' do
      it 'should grant access if permission allows it' do
        d10.access_checker.grants = g1

        params = { id: d10.id }

        s1 = TestDatumOneService.new(a1, params)
        expect(s1.success?).to eql(true)
        s2 = TestDatumOneService.new(a2, params)
        expect(s2.success?).to eql(true)

        # :show uses Fl::Core::Access::Permission::Read::NAME
        obj = s1.get_and_check('show')
        expect(s1.success?).to eql(true)
        expect(obj).to be_a(Fl::Core::TestDatumOne)
        expect(obj.fingerprint).to eql(d10.fingerprint)

        # :update uses Fl::Core::Access::Permission::Write::NAME
        obj = s1.get_and_check('update')
        expect(s1.success?).to eql(true)
        expect(obj).to be_a(Fl::Core::TestDatumOne)
        expect(obj.fingerprint).to eql(d10.fingerprint)

        # :show uses Fl::Core::Access::Permission::Read::NAME
        obj = s2.get_and_check('show')
        expect(s2.success?).to eql(true)
        expect(obj).to be_a(Fl::Core::TestDatumOne)
        expect(obj.fingerprint).to eql(d10.fingerprint)
      end

      it 'should deny access if permission denies it' do
        d10.access_checker.grants = g1

        params = { id: d10.id }

        s1 = TestDatumOneService.new(a1, params)
        expect(s1.success?).to eql(true)
        s2 = TestDatumOneService.new(a2, params)
        expect(s2.success?).to eql(true)

        # :destroy uses Fl::Core::Access::Permission::Delete::NAME
        obj = s1.get_and_check('destroy')
        expect(s1.success?).to eql(false)
        expect(obj).to be_nil
        _expect_no_permission(s1.status)

        # :update uses Fl::Core::Access::Permission::Write::NAME
        obj = s2.get_and_check('update')
        expect(s2.success?).to eql(false)
        expect(obj).to be_nil
        _expect_no_permission(s2.status)
      end

      it 'should deny access for an unknown action' do
        d10.access_checker.grants = g1

        params = { id: d10.id }

        s1 = TestDatumOneService.new(a1, params)
        expect(s1.success?).to eql(true)
        s2 = TestDatumOneService.new(a2, params)
        expect(s2.success?).to eql(true)

        obj = s1.get_and_check(:unknown)
        expect(s1.success?).to eql(false)
        expect(obj).to be_nil
        _expect_no_permission(s1.status)

        obj = s2.get_and_check('unknown')
        expect(s2.success?).to eql(false)
        expect(obj).to be_nil
        _expect_no_permission(s2.status)
      end

      it 'should deny access for an asset with no grants' do
        d10.access_checker.grants = [ ]

        params = { id: d10.id }

        s1 = TestDatumOneService.new(a1, params)
        expect(s1.success?).to eql(true)
        s2 = TestDatumOneService.new(a2, params)
        expect(s2.success?).to eql(true)

        obj = s1.get_and_check('show')
        expect(s1.success?).to eql(false)
        expect(obj).to be_nil
        _expect_no_permission(s1.status)

        obj = s2.get_and_check('show')
        expect(s2.success?).to eql(false)
        expect(obj).to be_nil
        _expect_no_permission(s2.status)
      end

      it 'should deny access for an actor with no grants' do
        d10.access_checker.grants = g1

        params = { id: d10.id }

        s3 = TestDatumOneService.new(a3, params)
        expect(s3.success?).to eql(true)

        obj = s3.get_and_check('destroy')
        expect(s3.success?).to eql(false)
        expect(obj).to be_nil
        _expect_no_permission(s3.status)
      end
    end
  end
end
