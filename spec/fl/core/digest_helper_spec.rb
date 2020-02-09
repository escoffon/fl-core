RSpec.describe Fl::Core::DigestHelper, type: :helper do
  let(:dh) { Fl::Core::DigestHelper }

  describe '.flatten' do
    it 'should flatten scalars as-is' do
      value = 'Test'
      expect(dh.flatten(value)).to eql(value.to_s)

      value = 10
      expect(dh.flatten(value)).to eql(value.to_s)

      value = 10.24
      expect(dh.flatten(value)).to eql(value.to_s)

      value = :test_here
      expect(dh.flatten(value)).to eql(value.to_s)

      value = true
      expect(dh.flatten(value)).to eql(value.to_s)

      value = false
      expect(dh.flatten(value)).to eql(value.to_s)

      value = nil
      expect(dh.flatten(value)).to eql('nil')
    end

    it 'should flatten arrays of scalars' do
      value = [ 'Test', 10, 10.24, :test_here, true, false, nil ]
      xl = '[' + value.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
      expect(dh.flatten(value)).to eql(xl)
    end

    it 'should flatten nested simple arrays' do
      sub1 = [ 'Sub1', 100 ]
      sub2 = [ 'Sub2', 100 ]
      value = [ 'Value', sub1, 200, [ 400, sub2 ] ]
      x1 = '[' + sub1.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
      x2 = '[' + sub2.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
      xl = "[Value,#{x1},200,[400,#{x2}]]"
      expect(dh.flatten(value)).to eql(xl)
    end

    it 'should flatten hashes' do
      value = { a: 1, b: 'two' }
      xl = '{a=>1,b=>two}'
      expect(dh.flatten(value)).to eql(xl)
    end

    it 'should flatten nested hashes' do
      value = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba' } } }
      xl = '{a=>1,b=>two,c=>{ca=>100,cb=>{cba=>scba}}}'
      expect(dh.flatten(value)).to eql(xl)
    end

    it 'should sort keys in hashes' do
      v1 = { z: 200, e: 400, b: 'two', a: 1, c: 'cv' }
      v2 = { c: 'cv', b: 'two', z: 200, e: 400, a: 1 }
      expect(dh.flatten(v1)).to eql(dh.flatten(v2))
    end

    it 'should sort keys in nested hashes' do
      v1 = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba', cbb: 600, cbc: 'scbc' }, cc: 240 } }
      v2 = { c: { cb: { cbc: 'scbc', cbb: 600, cba: 'scba' }, cc: 240, ca: 100 }, b: 'two', a: 1 }
      expect(dh.flatten(v1)).to eql(dh.flatten(v2))
    end
  end

  describe 'MD5' do
    context '.digest' do
      it 'should digest scalars' do
        value = 'Test'
        xd = Digest::MD5.digest(value.to_s)
        expect(dh::MD5.digest(value)).to eql(xd)

        value = 10
        xd = Digest::MD5.digest(value.to_s)
        expect(dh::MD5.digest(value)).to eql(xd)

        value = 10.24
        xd = Digest::MD5.digest(value.to_s)
        expect(dh::MD5.digest(value)).to eql(xd)

        value = :test_here
        xd = Digest::MD5.digest(value.to_s)
        expect(dh::MD5.digest(value)).to eql(xd)

        value = true
        xd = Digest::MD5.digest(value.to_s)
        expect(dh::MD5.digest(value)).to eql(xd)

        value = false
        xd = Digest::MD5.digest(value.to_s)
        expect(dh::MD5.digest(value)).to eql(xd)

        value = nil
        xd = Digest::MD5.digest('nil')
        expect(dh::MD5.digest(value)).to eql(xd)
      end

      it 'should digest arrays of scalars' do
        value = [ 'Test', 10, 10.24, :test_here, true, false, nil ]
        xd = Digest::MD5.digest("[Test,10,#{(10.24).to_s},test_here,true,false,nil]")
        expect(dh::MD5.digest(value)).to eql(xd)
      end

      it 'should digest nested simple arrays' do
        sub1 = [ 'Sub1', 100 ]
        sub2 = [ 'Sub2', 100 ]
        value = [ 'Value', sub1, 200, [ 400, sub2 ] ]
        x1 = '[' + sub1.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        x2 = '[' + sub2.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        xd = Digest::MD5.digest("[Value,#{x1},200,[400,#{x2}]]")
        expect(dh::MD5.digest(value)).to eql(xd)
      end

      it 'should gighest hashes' do
        value = { a: 1, b: 'two' }
        xd = Digest::MD5.digest('{a=>1,b=>two}')
        expect(dh::MD5.digest(value)).to eql(xd)
      end

      it 'should digest nested hashes' do
        value = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba' } } }
        xd = Digest::MD5.digest('{a=>1,b=>two,c=>{ca=>100,cb=>{cba=>scba}}}')
        expect(dh::MD5.digest(value)).to eql(xd)
      end

      it 'should generate the same digest for equivalent hashes' do
        v1 = { z: 200, e: 400, b: 'two', a: 1, c: 'cv' }
        v2 = { c: 'cv', b: 'two', z: 200, e: 400, a: 1 }
        expect(dh::MD5.digest(v1)).to eql(dh::MD5.digest(v2))
      end

      it 'should generate the same digest for equivalent nested hashes' do
        v1 = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba', cbb: 600, cbc: 'scbc' }, cc: 240 } }
        v2 = { c: { cb: { cbc: 'scbc', cbb: 600, cba: 'scba' }, cc: 240, ca: 100 }, b: 'two', a: 1 }
        expect(dh::MD5.digest(v1)).to eql(dh::MD5.digest(v2))
      end
    end

    context '.hexdigest' do
      it 'should digest scalars' do
        value = 'Test'
        xd = Digest::MD5.hexdigest(value.to_s)
        expect(dh::MD5.hexdigest(value)).to eql(xd)

        value = 10
        xd = Digest::MD5.hexdigest(value.to_s)
        expect(dh::MD5.hexdigest(value)).to eql(xd)

        value = 10.24
        xd = Digest::MD5.hexdigest(value.to_s)
        expect(dh::MD5.hexdigest(value)).to eql(xd)

        value = :test_here
        xd = Digest::MD5.hexdigest(value.to_s)
        expect(dh::MD5.hexdigest(value)).to eql(xd)

        value = true
        xd = Digest::MD5.hexdigest(value.to_s)
        expect(dh::MD5.hexdigest(value)).to eql(xd)

        value = false
        xd = Digest::MD5.hexdigest(value.to_s)
        expect(dh::MD5.hexdigest(value)).to eql(xd)

        value = nil
        xd = Digest::MD5.hexdigest('nil')
        expect(dh::MD5.hexdigest(value)).to eql(xd)
      end

      it 'should digest arrays of scalars' do
        value = [ 'Test', 10, 10.24, :test_here, true, false, nil ]
        xd = Digest::MD5.hexdigest("[Test,10,#{(10.24).to_s},test_here,true,false,nil]")
        expect(dh::MD5.hexdigest(value)).to eql(xd)
      end

      it 'should digest nested simple arrays' do
        sub1 = [ 'Sub1', 100 ]
        sub2 = [ 'Sub2', 100 ]
        value = [ 'Value', sub1, 200, [ 400, sub2 ] ]
        x1 = '[' + sub1.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        x2 = '[' + sub2.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        xd = Digest::MD5.hexdigest("[Value,#{x1},200,[400,#{x2}]]")
        expect(dh::MD5.hexdigest(value)).to eql(xd)
      end

      it 'should gighest hashes' do
        value = { a: 1, b: 'two' }
        xd = Digest::MD5.hexdigest('{a=>1,b=>two}')
        expect(dh::MD5.hexdigest(value)).to eql(xd)
      end

      it 'should digest nested hashes' do
        value = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba' } } }
        xd = Digest::MD5.hexdigest('{a=>1,b=>two,c=>{ca=>100,cb=>{cba=>scba}}}')
        expect(dh::MD5.hexdigest(value)).to eql(xd)
      end

      it 'should generate the same digest for equivalent hashes' do
        v1 = { z: 200, e: 400, b: 'two', a: 1, c: 'cv' }
        v2 = { c: 'cv', b: 'two', z: 200, e: 400, a: 1 }
        expect(dh::MD5.hexdigest(v1)).to eql(dh::MD5.hexdigest(v2))
      end

      it 'should generate the same digest for equivalent nested hashes' do
        v1 = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba', cbb: 600, cbc: 'scbc' }, cc: 240 } }
        v2 = { c: { cb: { cbc: 'scbc', cbb: 600, cba: 'scba' }, cc: 240, ca: 100 }, b: 'two', a: 1 }
        expect(dh::MD5.hexdigest(v1)).to eql(dh::MD5.hexdigest(v2))
      end
    end

    context '.base64digest' do
      it 'should digest scalars' do
        value = 'Test'
        xd = Digest::MD5.base64digest(value.to_s)
        expect(dh::MD5.base64digest(value)).to eql(xd)

        value = 10
        xd = Digest::MD5.base64digest(value.to_s)
        expect(dh::MD5.base64digest(value)).to eql(xd)

        value = 10.24
        xd = Digest::MD5.base64digest(value.to_s)
        expect(dh::MD5.base64digest(value)).to eql(xd)

        value = :test_here
        xd = Digest::MD5.base64digest(value.to_s)
        expect(dh::MD5.base64digest(value)).to eql(xd)

        value = true
        xd = Digest::MD5.base64digest(value.to_s)
        expect(dh::MD5.base64digest(value)).to eql(xd)

        value = false
        xd = Digest::MD5.base64digest(value.to_s)
        expect(dh::MD5.base64digest(value)).to eql(xd)

        value = nil
        xd = Digest::MD5.base64digest('nil')
        expect(dh::MD5.base64digest(value)).to eql(xd)
      end

      it 'should digest arrays of scalars' do
        value = [ 'Test', 10, 10.24, :test_here, true, false, nil ]
        xd = Digest::MD5.base64digest("[Test,10,#{(10.24).to_s},test_here,true,false,nil]")
        expect(dh::MD5.base64digest(value)).to eql(xd)
      end

      it 'should digest nested simple arrays' do
        sub1 = [ 'Sub1', 100 ]
        sub2 = [ 'Sub2', 100 ]
        value = [ 'Value', sub1, 200, [ 400, sub2 ] ]
        x1 = '[' + sub1.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        x2 = '[' + sub2.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        xd = Digest::MD5.base64digest("[Value,#{x1},200,[400,#{x2}]]")
        expect(dh::MD5.base64digest(value)).to eql(xd)
      end

      it 'should gighest hashes' do
        value = { a: 1, b: 'two' }
        xd = Digest::MD5.base64digest('{a=>1,b=>two}')
        expect(dh::MD5.base64digest(value)).to eql(xd)
      end

      it 'should digest nested hashes' do
        value = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba' } } }
        xd = Digest::MD5.base64digest('{a=>1,b=>two,c=>{ca=>100,cb=>{cba=>scba}}}')
        expect(dh::MD5.base64digest(value)).to eql(xd)
      end

      it 'should generate the same digest for equivalent hashes' do
        v1 = { z: 200, e: 400, b: 'two', a: 1, c: 'cv' }
        v2 = { c: 'cv', b: 'two', z: 200, e: 400, a: 1 }
        expect(dh::MD5.base64digest(v1)).to eql(dh::MD5.base64digest(v2))
      end

      it 'should generate the same digest for equivalent nested hashes' do
        v1 = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba', cbb: 600, cbc: 'scbc' }, cc: 240 } }
        v2 = { c: { cb: { cbc: 'scbc', cbb: 600, cba: 'scba' }, cc: 240, ca: 100 }, b: 'two', a: 1 }
        expect(dh::MD5.base64digest(v1)).to eql(dh::MD5.base64digest(v2))
      end
    end
  end

  describe 'SHA1' do
    context '.digest' do
      it 'should digest scalars' do
        value = 'Test'
        xd = Digest::SHA1.digest(value.to_s)
        expect(dh::SHA1.digest(value)).to eql(xd)

        value = 10
        xd = Digest::SHA1.digest(value.to_s)
        expect(dh::SHA1.digest(value)).to eql(xd)

        value = 10.24
        xd = Digest::SHA1.digest(value.to_s)
        expect(dh::SHA1.digest(value)).to eql(xd)

        value = :test_here
        xd = Digest::SHA1.digest(value.to_s)
        expect(dh::SHA1.digest(value)).to eql(xd)

        value = true
        xd = Digest::SHA1.digest(value.to_s)
        expect(dh::SHA1.digest(value)).to eql(xd)

        value = false
        xd = Digest::SHA1.digest(value.to_s)
        expect(dh::SHA1.digest(value)).to eql(xd)

        value = nil
        xd = Digest::SHA1.digest('nil')
        expect(dh::SHA1.digest(value)).to eql(xd)
      end

      it 'should digest arrays of scalars' do
        value = [ 'Test', 10, 10.24, :test_here, true, false, nil ]
        xd = Digest::SHA1.digest("[Test,10,#{(10.24).to_s},test_here,true,false,nil]")
        expect(dh::SHA1.digest(value)).to eql(xd)
      end

      it 'should digest nested simple arrays' do
        sub1 = [ 'Sub1', 100 ]
        sub2 = [ 'Sub2', 100 ]
        value = [ 'Value', sub1, 200, [ 400, sub2 ] ]
        x1 = '[' + sub1.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        x2 = '[' + sub2.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        xd = Digest::SHA1.digest("[Value,#{x1},200,[400,#{x2}]]")
        expect(dh::SHA1.digest(value)).to eql(xd)
      end

      it 'should gighest hashes' do
        value = { a: 1, b: 'two' }
        xd = Digest::SHA1.digest('{a=>1,b=>two}')
        expect(dh::SHA1.digest(value)).to eql(xd)
      end

      it 'should digest nested hashes' do
        value = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba' } } }
        xd = Digest::SHA1.digest('{a=>1,b=>two,c=>{ca=>100,cb=>{cba=>scba}}}')
        expect(dh::SHA1.digest(value)).to eql(xd)
      end

      it 'should generate the same digest for equivalent hashes' do
        v1 = { z: 200, e: 400, b: 'two', a: 1, c: 'cv' }
        v2 = { c: 'cv', b: 'two', z: 200, e: 400, a: 1 }
        expect(dh::SHA1.digest(v1)).to eql(dh::SHA1.digest(v2))
      end

      it 'should generate the same digest for equivalent nested hashes' do
        v1 = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba', cbb: 600, cbc: 'scbc' }, cc: 240 } }
        v2 = { c: { cb: { cbc: 'scbc', cbb: 600, cba: 'scba' }, cc: 240, ca: 100 }, b: 'two', a: 1 }
        expect(dh::SHA1.digest(v1)).to eql(dh::SHA1.digest(v2))
      end
    end

    context '.hexdigest' do
      it 'should digest scalars' do
        value = 'Test'
        xd = Digest::SHA1.hexdigest(value.to_s)
        expect(dh::SHA1.hexdigest(value)).to eql(xd)

        value = 10
        xd = Digest::SHA1.hexdigest(value.to_s)
        expect(dh::SHA1.hexdigest(value)).to eql(xd)

        value = 10.24
        xd = Digest::SHA1.hexdigest(value.to_s)
        expect(dh::SHA1.hexdigest(value)).to eql(xd)

        value = :test_here
        xd = Digest::SHA1.hexdigest(value.to_s)
        expect(dh::SHA1.hexdigest(value)).to eql(xd)

        value = true
        xd = Digest::SHA1.hexdigest(value.to_s)
        expect(dh::SHA1.hexdigest(value)).to eql(xd)

        value = false
        xd = Digest::SHA1.hexdigest(value.to_s)
        expect(dh::SHA1.hexdigest(value)).to eql(xd)

        value = nil
        xd = Digest::SHA1.hexdigest('nil')
        expect(dh::SHA1.hexdigest(value)).to eql(xd)
      end

      it 'should digest arrays of scalars' do
        value = [ 'Test', 10, 10.24, :test_here, true, false, nil ]
        xd = Digest::SHA1.hexdigest("[Test,10,#{(10.24).to_s},test_here,true,false,nil]")
        expect(dh::SHA1.hexdigest(value)).to eql(xd)
      end

      it 'should digest nested simple arrays' do
        sub1 = [ 'Sub1', 100 ]
        sub2 = [ 'Sub2', 100 ]
        value = [ 'Value', sub1, 200, [ 400, sub2 ] ]
        x1 = '[' + sub1.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        x2 = '[' + sub2.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        xd = Digest::SHA1.hexdigest("[Value,#{x1},200,[400,#{x2}]]")
        expect(dh::SHA1.hexdigest(value)).to eql(xd)
      end

      it 'should gighest hashes' do
        value = { a: 1, b: 'two' }
        xd = Digest::SHA1.hexdigest('{a=>1,b=>two}')
        expect(dh::SHA1.hexdigest(value)).to eql(xd)
      end

      it 'should digest nested hashes' do
        value = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba' } } }
        xd = Digest::SHA1.hexdigest('{a=>1,b=>two,c=>{ca=>100,cb=>{cba=>scba}}}')
        expect(dh::SHA1.hexdigest(value)).to eql(xd)
      end

      it 'should generate the same digest for equivalent hashes' do
        v1 = { z: 200, e: 400, b: 'two', a: 1, c: 'cv' }
        v2 = { c: 'cv', b: 'two', z: 200, e: 400, a: 1 }
        expect(dh::SHA1.hexdigest(v1)).to eql(dh::SHA1.hexdigest(v2))
      end

      it 'should generate the same digest for equivalent nested hashes' do
        v1 = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba', cbb: 600, cbc: 'scbc' }, cc: 240 } }
        v2 = { c: { cb: { cbc: 'scbc', cbb: 600, cba: 'scba' }, cc: 240, ca: 100 }, b: 'two', a: 1 }
        expect(dh::SHA1.hexdigest(v1)).to eql(dh::SHA1.hexdigest(v2))
      end
    end

    context '.base64digest' do
      it 'should digest scalars' do
        value = 'Test'
        xd = Digest::SHA1.base64digest(value.to_s)
        expect(dh::SHA1.base64digest(value)).to eql(xd)

        value = 10
        xd = Digest::SHA1.base64digest(value.to_s)
        expect(dh::SHA1.base64digest(value)).to eql(xd)

        value = 10.24
        xd = Digest::SHA1.base64digest(value.to_s)
        expect(dh::SHA1.base64digest(value)).to eql(xd)

        value = :test_here
        xd = Digest::SHA1.base64digest(value.to_s)
        expect(dh::SHA1.base64digest(value)).to eql(xd)

        value = true
        xd = Digest::SHA1.base64digest(value.to_s)
        expect(dh::SHA1.base64digest(value)).to eql(xd)

        value = false
        xd = Digest::SHA1.base64digest(value.to_s)
        expect(dh::SHA1.base64digest(value)).to eql(xd)

        value = nil
        xd = Digest::SHA1.base64digest('nil')
        expect(dh::SHA1.base64digest(value)).to eql(xd)
      end

      it 'should digest arrays of scalars' do
        value = [ 'Test', 10, 10.24, :test_here, true, false, nil ]
        xd = Digest::SHA1.base64digest("[Test,10,#{(10.24).to_s},test_here,true,false,nil]")
        expect(dh::SHA1.base64digest(value)).to eql(xd)
      end

      it 'should digest nested simple arrays' do
        sub1 = [ 'Sub1', 100 ]
        sub2 = [ 'Sub2', 100 ]
        value = [ 'Value', sub1, 200, [ 400, sub2 ] ]
        x1 = '[' + sub1.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        x2 = '[' + sub2.map { |e| (e.nil?) ? 'nil' : e.to_s }.join(',') + ']'
        xd = Digest::SHA1.base64digest("[Value,#{x1},200,[400,#{x2}]]")
        expect(dh::SHA1.base64digest(value)).to eql(xd)
      end

      it 'should gighest hashes' do
        value = { a: 1, b: 'two' }
        xd = Digest::SHA1.base64digest('{a=>1,b=>two}')
        expect(dh::SHA1.base64digest(value)).to eql(xd)
      end

      it 'should digest nested hashes' do
        value = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba' } } }
        xd = Digest::SHA1.base64digest('{a=>1,b=>two,c=>{ca=>100,cb=>{cba=>scba}}}')
        expect(dh::SHA1.base64digest(value)).to eql(xd)
      end

      it 'should generate the same digest for equivalent hashes' do
        v1 = { z: 200, e: 400, b: 'two', a: 1, c: 'cv' }
        v2 = { c: 'cv', b: 'two', z: 200, e: 400, a: 1 }
        expect(dh::SHA1.base64digest(v1)).to eql(dh::SHA1.base64digest(v2))
      end

      it 'should generate the same digest for equivalent nested hashes' do
        v1 = { a: 1, b: 'two', c: { ca: 100, cb: { cba: 'scba', cbb: 600, cbc: 'scbc' }, cc: 240 } }
        v2 = { c: { cb: { cbc: 'scbc', cbb: 600, cba: 'scba' }, cc: 240, ca: 100 }, b: 'two', a: 1 }
        expect(dh::SHA1.base64digest(v1)).to eql(dh::SHA1.base64digest(v2))
      end
    end
  end
end
