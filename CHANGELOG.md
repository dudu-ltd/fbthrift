## 1.0.0+6
- fix: ByteArrayOutputStream length cannot be increased

## 1.0.0+5
- fix: value overflow issue when int64 exceeds 4611686018427387904.
- fix: make the write buffer of TFramedTransport consistent with the Java version.
- fix: make TMemoryInputTransport consistent with the Java version.

## 1.0.0+4
- fix: data error in TCompactProtocol.readDouble 

## 1.0.0+3
- fix: oneway supports

## 1.0.0+2
- fix bugs 
- feat: adding maxLength specification
- enhance: when socket is nested in a frame, parse the length of the frame first.

## 1.0.0+1
- add more docs

## 1.0.0

- Initial version.
