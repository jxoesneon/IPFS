# dart_ipfs Roadmap

**Current Version**: 1.11.5 (Multi-Platform Production Ready)  
**Last Updated**: 2026-06-23

---

## 📍 Current Status

dart_ipfs **v1.11.5** is **multi-platform production ready** with:

- ✅ **IpfsPlatform**: Unified abstraction layer for IO and Web.
- ✅ **WebRTC Multiplexing**: Native p2p connectivity for browsers with standard libp2p stream support.
- ✅ **Bitswap Smart Routing**: Efficient block exchange with provider tracking.
- ✅ **90% Code Coverage**: Robust test suite with cross-platform validation.
- ✅ **Security Parity**: Unified security management across IO and Web platforms.

---

## 🗓️ Version Timeline

### v1.10 - Q1 2026 (The Multi-Platform Milestone)

**Focus**: Browser compatibility, storage abstraction, and unified API.

#### Features
- [x] IpfsPlatform abstraction layer.
- [x] IndexedDB storage provider for Web.
- [x] Browser-compatible SecurityManager.
- [x] Automated Chrome/Firefox testing suite.
- [x] Protocol standardization (Kubo compliance).

**Released**: February 2026

---

### v1.11 - Q2 2026 (Enhanced Connectivity)

**Focus**: Advanced browser networking and performance.

#### Features
- [x] Libp2p browser transport (WebRTC/WebTransport).
- [x] IPNS performance optimizations (DHT record caching).
- [x] Advanced IPLD codecs (DagCbor, DagJson, DagJose).
- [x] Flutter Web specific optimizations.
- [x] Multi-platform metrics dashboard.

**Released**: May 2026

---

### v2.0 - Q4 2026 (Ecosystem & Extensibility)

**Focus**: Speed and efficiency

#### Features

- [x] MFS (Mutable File System)
- [ ] Parallel block fetching
- [ ] Smart caching with ML
- [ ] Connection pooling
- [ ] Bandwidth shaping

#### Improvements

- [ ] Content routing optimization
- [ ] Multi-algorithm compression
- [ ] Binary size optimization
- [ ] Memory usage improvements

**Estimated Release**: September 2026

---

### v2.1 - Q1 2027 (Advanced Features)

**Focus**: Ecosystem and extensibility

#### Major Features

- [ ] Plugin system architecture
- [ ] QUIC transport
- [ ] Native Ed25519/X25519 crypto
- [ ] Advanced hole punching
- [ ] Chaos engineering framework

#### Breaking Changes

- Improved configuration API (more structured)
- Plugin-based architecture (optional)
- Enhanced type safety

**Estimated Release**: March 2027

---

### v2.1 - Q1 2027 (Security & Privacy)

**Focus**: Enterprise and privacy features

#### Features

- [ ] HSM (Hardware Security Module) support
- [ ] Content policy engine
- [ ] Multi-signature IPNS
- [ ] Zero-knowledge proof support
- [ ] Enhanced audit logging

#### Improvements

- [ ] Enterprise compliance features
- [ ] Advanced access control
- [ ] Privacy-preserving routing

**Estimated Release**: March 2027

---

### v2.2 - Q2 2027 (Developer Tools)

**Focus**: Developer experience

#### Features

- [ ] VS Code extension
- [ ] IntelliJ plugin
- [ ] Code generation tools
- [ ] Interactive tutorials
- [ ] Web dashboard UI

#### Improvements

- [ ] Hot reload support
- [ ] Better debugging tools
- [ ] Integration examples
- [ ] Video tutorial series

**Estimated Release**: June 2027

---

### v3.0 - Q3 2027+ (Innovation)

**Focus**: Next-generation features

#### Experimental

- [ ] Web Assembly build
- [ ] Marketplace integration
- [ ] Desktop native app
- [ ] IPFS over Bluetooth
- [ ] AI-powered content discovery
- [ ] Quantum-safe cryptography

**Estimated Release**: September 2027+

---

## 🎯 Feature Categories

### High Priority (Next 3 Versions)

#### 1. Cryptography Enhancement

- **v1.2**: Native Ed25519/X25519 implementation
- **Why**: Better libp2p compatibility, faster crypto operations
- **Status**: ✅ Completed (v1.2.1)

#### 2. Transport Improvements

- **v1.2**: WebRTC transport for browser compatibility
- **v2.0**: QUIC transport for better performance
- **Why**: Broader platform support, faster connections
- **Effort**: 4-6 weeks each
- **Status**: Planned

#### 3. Mutable File System (MFS)

- **v1.11.5**: Full MFS implementation
- **Why**: Familiar file system interface, better DX
- **Effort**: 6-8 weeks
- **Status**: ✅ Completed

#### 4. Plugin System

- **v2.0**: Extensible plugin architecture
- **Why**: Community contributions, custom protocols
- **Effort**: 8-10 weeks
- **Status**: Planned

### Medium Priority (Future Versions)

#### 5. Performance Optimization

- Parallel block fetching
- Smart caching
- Connection pooling
- Compression improvements

#### 6. Developer Experience

- CLI enhancements
- Flutter widgets
- IDE plugins
- Code generators

#### 7. Security Features

- HSM support
- Content policies
- Multi-sig IPNS
- ZK proofs

#### 8. Platform-Specific

- Mobile optimizations
- Web Assembly
- Desktop app
- Browser extensions

### Low Priority (Long-term)

#### 9. Experimental Features

- Bluetooth transport
- AI content discovery
- Quantum-safe crypto
- Marketplace integration

---

## 🚀 Quick Wins

These can be implemented quickly with high impact:

### Immediate (Next Release)

1. **Docker Images** (1 week)
   - Official Docker Hub images
   - Multiple variants (gateway, full-node, dev)
2. **Health Checks** (1 week)

   - Kubernetes-ready endpoints
   - Load balancer integration

3. **Structured Logging** (1 week)

   - JSON log format
   - Better log aggregation

4. **Template Library** (1-2 weeks)
   - Project scaffolding
   - Common use cases

### Short-term (Next Quarter)

1. **Enhanced CLI** (2-3 weeks)

   - Full feature parity with API
   - Better UX

2. **Flutter Widgets** (3-4 weeks)

   - Pre-built UI components
   - Mobile app acceleration

3. **API Docs Site** (2-3 weeks)
   - Searchable documentation
   - Examples and guides

---

## 📊 Effort Estimation

### Development Time by Category

| Category               | Total Effort | Priority | Timeline   |
| ---------------------- | ------------ | -------- | ---------- |
| **Crypto Enhancement** | 2-3 weeks    | High     | v1.2       |
| **Transport Layers**   | 8-12 weeks   | High     | v1.2, v2.0 |
| **MFS**                | 6-8 weeks    | High     | v1.3       |
| **Plugin System**      | 8-10 weeks   | High     | v2.0       |
| **Performance**        | 12-16 weeks  | Medium   | v1.3       |
| **Developer Tools**    | 10-14 weeks  | Medium   | v2.2       |
| **Security**           | 12-16 weeks  | Medium   | v2.1       |
| **Platform-Specific**  | 16-20 weeks  | Low      | v2.0+      |
| **Experimental**       | Ongoing      | Low      | v3.0+      |

---

## 🎓 Community Contributions

We welcome contributions in these areas:

### Good First Issues

- Documentation improvements
- Example applications
- Bug fixes
- Test coverage
- Performance benchmarks

### Help Wanted

- Mobile platform optimizations
- Browser compatibility testing
- Integration examples
- Translation/i18n

### Advanced

- Protocol implementations
- Transport layers
- Cryptography improvements
- Plugin development

---

## 📈 Success Metrics

### v1.x Goals

- [ ] 1000+ stars on GitHub
- [ ] 50+ production deployments
- [ ] 10+ community contributors
- [ ] 95%+ test coverage maintained

### v2.x Goals

- [ ] 5000+ downloads per month
- [ ] 100+ production deployments
- [ ] 50+ community contributors
- [ ] 20+ plugins available

### v3.x Goals

- [ ] 10,000+ active users
- [ ] Feature parity with go-ipfs
- [ ] Official IPFS implementation status
- [ ] Vibrant plugin ecosystem

---

## 🤝 How to Contribute

### Areas We Need Help

1. **Documentation**

   - Tutorial writing
   - API documentation
   - Example applications
   - Translation

2. **Testing**

   - Integration tests
   - Platform testing
   - Performance benchmarks
   - Protocol compliance

3. **Features**

   - See "Good First Issues" label
   - Check roadmap for planned features
   - Propose new features via discussions

4. **Community**
   - Answer questions
   - Write blog posts
   - Give talks
   - Share projects

### Process

1. Check existing issues and discussions
2. Propose changes via issue or discussion
3. Get feedback from maintainers
4. Submit PR with tests and docs
5. Code review and merge

---

## 🔮 Long-term Vision

### dart_ipfs in 2027

- **Primary IPFS implementation for Dart/Flutter**
- **100% feature parity with go-ipfs**
- **Thriving plugin ecosystem**
- **Production-ready for all platforms**
- **First-class mobile IPFS experience**
- **Leading in performance and DX**

### Strategic Goals

1. **Become official IPFS implementation**
2. **Power 1000+ production apps**
3. **Enable IPFS on mobile at scale**
4. **Bootstrap decentralized web on Dart**

---

## 📞 Stay Updated

- **GitHub Releases**: Follow for version updates
- **GitHub Discussions**: Feature discussions and feedback
- **GitHub Issues**: Bug reports and feature requests
- **README**: Current status and quick start

---

## 📝 Notes

### Version Numbering

- **Major (x.0.0)**: Breaking changes, major features
- **Minor (1.x.0)**: New features, no breaking changes
- **Patch (1.0.x)**: Bug fixes, minor improvements

### Timeline Flexibility

Dates are estimates and may change based on:

- Community contributions
- Priority shifts
- Resource availability
- Feedback and needs

### Feedback Welcome

This roadmap is a living document. We welcome:

- Feature suggestions
- Priority feedback
- Timeline input
- Use case discussions

---

**Last Updated**: 2026-06-23 (v1.11.5)
**Status**: Active Development  
**Current Version:** 1.11.5
**Target for Next Release:** 2.0.0 (Q4 2026)
