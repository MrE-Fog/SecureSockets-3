// =====================================================================================================================
//
//  File:       SecureSockets.Ctx.swift
//  Project:    SecureSockets
//
//  Version:    0.3.1
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/projects/securesockets/securesockets.html
//  Blog:       http://swiftrien.blogspot.com
//  Git:        https://github.com/Balancingrock/SecureSockets
//
//  Copyright:  (c) 2016-2017 Marinus van der Lugt, All rights reserved.
//
//  License:    Use or redistribute this code any way you like with the following two provision:
//
//  1) You ACCEPT this source code AS IS without any guarantees that it will work as intended. Any liability from its
//  use is YOURS.
//
//  2) You WILL NOT seek damages from the author or balancingrock.nl.
//
//  I also ask you to please leave this header with the source code.
//
//  I strongly believe that the Non Agression Principle is the way for societies to function optimally. I thus reject
//  the implicit use of force to extract payment. Since I cannot negotiate with you about the price of this code, I
//  have choosen to leave it up to you to determine its price. You pay me whatever you think this code is worth to you.
//
//   - You can send payment via paypal to: sales@balancingrock.nl
//   - Or wire bitcoins to: 1GacSREBxPy1yskLMc9de2nofNv2SNdwqH
//
//  I prefer the above two, but if these options don't suit you, you can also send me a gift from my amazon.co.uk
//  wishlist: http://www.amazon.co.uk/gp/registry/wishlist/34GNMPZKAQ0OO/ref=cm_sw_em_r_wsl_cE3Tub013CKN6_wb
//
//  If you like to pay in another way, please contact me at rien@balancingrock.nl
//
//  (It is always a good idea to visit the website/blog/google to ensure that you actually pay me and not some imposter)
//
//  For private and non-profit use the suggested price is the price of 1 good cup of coffee, say $4.
//  For commercial use the suggested price is the price of 1 good meal, say $20.
//
//  You are however encouraged to pay more ;-)
//
//  Prices/Quotes for support, modifications or enhancements can be obtained from: rien@balancingrock.nl
//
// =====================================================================================================================
// PLEASE let me know about bugs, improvements and feature requests. (rien@balancingrock.nl)
// =====================================================================================================================
//
// History
//
// v0.3.1  - Updated documentation for use with jazzy.
// v0.3.0  - Fixed error message text (removed reference to SwifterSockets.Secure)
// v0.1.0  - Initial release
// =====================================================================================================================

import Foundation
import SwifterSockets
import COpenSsl


/// A wrapper class for an openSSL context (SSL_CTX).

public class Ctx {
    
    
    /// The pointer to the openSSL context structure
    
    private(set) var optr: OpaquePointer
    
    
    // Free's the openSSl structure
    
    deinit { SSL_CTX_free(optr) }
    
    
    /// Initialises a new object from the given opaquepointer. The (openSSL) reference count of the structure must be 1.
    ///
    /// - Parameter ctx: A pointer to a SSL_CTX structure with an reference count of 1.
    
    public init(ctx: OpaquePointer) { self.optr = ctx }
    
    
    /// The certificate for this context (if any).
    
    public var x509: X509? { return X509(ctx: self) }
    
    
    // A list with Ctx's for domains beiing hosted by the server that uses this Ctx. Should be empty for client Ctx's. May be empty for server Ctx's if the server hosts just one domain.
    
    private var domainCtxs = [Ctx]()
    
    
    /// Assigns the certificate in the given file.
    ///
    /// - Parameter file: An encoded file in PEM or ASN1 format with the certificate.
    ///
    /// - Returns: Either .success(true) or .error(message: String).
    
    public func useCertificate(file encodedFile: EncodedFile) -> Result<Bool> {
        
        ERR_clear_error()
        
        if SSL_CTX_use_certificate_file(optr, encodedFile.path, encodedFile.encoding) != 1 {
            
            return .error(message: "SecureSockets.Ctx.Ctx.useCertificate: Could not add certificate to CTX,\n\n\(errPrintErrors())")
            
        } else {
            
            return .success(true)
        }
    }
    
    
    /// Assigns the private key in the given file.
    ///
    /// - Parameter file: An encoded file in PEM or ASN1 format with the private key.
    ///
    /// - Returns: Either .success(true) or .error(message: String).
    
    public func usePrivateKey(file encodedFile: EncodedFile) -> Result<Bool> {
        
        ERR_clear_error()
        
        if SSL_CTX_use_PrivateKey_file(optr, encodedFile.path, encodedFile.encoding) != 1 {
            
            return .error(message: "SecureSockets.Ctx.Ctx.usePrivateKey: Could not add private key to CTX,\n\n\(errPrintErrors())")
            
        } else {
            
            return .success(true)
        }
    }
    
    
    /// Verifies if the private key and the certificate that were last set belong together.
    ///
    /// The private key most recently set will be tested for compatibilty with the public key in the certificate that was most recently set.
    ///
    /// - Returns: Either .success(true) or .error(message: String).
    
    public func checkPrivateKey() -> Result<Bool> {
        
        ERR_clear_error()
        
        if SSL_CTX_check_private_key(optr) != 1 {
            
            return .error(message: "SecureSockets.Ctx.Ctx.checkPrivateKey: Private Key check failed,\n\n\(errPrintErrors)")
            
        } else {
            
            return .success(true)
        }
    }
    
    
    /// Adds the file or folder at the given path to the list of trusted certificates.
    ///
    /// - Note: There is no test performed on the trusted certificated, the paths are accepted as is.
    ///
    /// - Parameter location: The path of the file or folder containing the trusted certificate(s).
    ///
    /// - Returns: Either .success(true) or .error(message: String)
    
    public func loadVerify(location path: String) -> Result<Bool> {
        
        var isDirectory: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            
            ERR_clear_error()
            
            if isDirectory.boolValue {
                
                if SSL_CTX_load_verify_locations(optr, nil, path) != 1 {
                    
                    return .error(message: "SecureSockets.Ctx.Ctx.loadVerify: Could not set verify location for folder \(path),\n\n'\(errPrintErrors())")
                }
                
            } else {
                
                if SSL_CTX_load_verify_locations(optr, path, nil) != 1 {
                    
                    return .error(message: "SecureSockets.Ctx.Ctx.loadVerify: Could not set verify location for file \(path),\n\n'\(errPrintErrors())")
                }
            }
            
        } else {
            
            return .error(message: "SecureSockets.Ctx.Ctx.loadVerify: File or folder no longer exists at \(path)")
        }
        
        return .success(true)
    }
    
    
    /// Sets the 'SSL_VERIFY_PEER' and 'SSL_VERIFY_FAIL_IF_NO_PEER_CERT' options to true.
    ///
    /// This enforces the verification of the certificate from the peer. The peer can be either a server or client.
    
    public func setVerifyPeer() {
        
        SSL_CTX_set_verify(optr, SSL_VERIFY_PEER + SSL_VERIFY_FAIL_IF_NO_PEER_CERT, nil)
    }
    
    
    /// This adds a domain Ctx. The Ctx should have a certificate and private key. The given Ctx is accepted as is without aditional checks.
    ///
    /// - Parameter ctx: The Ctx to be added.
    
    public func addDomainCtx(_ ctx: Ctx) {
        
        
        // If this is the first domain added, then install the SNI callback.
        
        if domainCtxs.count == 0 {
            sslCtxSetTlsExtServernameCallback(optr, sni_callback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        }
        
        
        // Add the ctx
        
        domainCtxs.append(ctx)
    }
    
    
    // The callback from openSSL. This callback must be installed before the server is started.
    
    private let sni_callback: @convention(c) (_ ssl: OpaquePointer?, _ num: UnsafeMutablePointer<Int32>?, _ arg: UnsafeMutableRawPointer?) -> Int32 = {
        
        (ssl_ptr, _, arg) -> Int32 in
        
        
        // Get the reference to 'self'
        
        let ourself = Unmanaged<Ctx>.fromOpaque(arg!).takeUnretainedValue()
        
        
        // Get the String with the host name from the SSL session
        
        guard let hostname = SSL_get_servername(ssl_ptr, TLSEXT_NAMETYPE_host_name) else { return SSL_TLSEXT_ERR_NOACK }
        
        
        // Check if the current certificate contains the hostname
        
        if let ctx_ptr = SSL_get_SSL_CTX(ssl_ptr) {
            
            if let x509_ptr = SSL_CTX_get0_certificate(ctx_ptr) {
                
                if X509_check_host(x509_ptr, hostname, 0, 0, nil) == 1 {
                    
                    return SSL_TLSEXT_ERR_OK
                }
            }
        }
        
        
        // Check if there is another CXT with a certificate containing the hostname
        
        var foundCtx: Ctx?
        for testCtx in ourself.domainCtxs {
            if testCtx.x509?.checkHost(hostname) ?? false {
                foundCtx = testCtx
                break
            }
        }
        guard let newCtx = foundCtx else  { return SSL_TLSEXT_ERR_NOACK }
        
        
        // Set the new CTX to the current SSL session
        
        if SSL_set_SSL_CTX(ssl_ptr, newCtx.optr) == nil {
            // The new ctx did not have a certificate (found by source code inspection of ssl_lib.c)
            // This should be impossible since that would have caused this CTX to be rejected
            return SSL_TLSEXT_ERR_NOACK
        }
        
        
        return SSL_TLSEXT_ERR_OK
    }
}


/// A context for a server.

public final class ServerCtx: Ctx {
    
    /// Creates a new ServerCtx.
    ///
    /// If the creations fails, the SecureSockets.errPrintErrors may have more information on the cause.
    
    public init?() {
        
        ERR_clear_error()
        
        
        // Create server context
        
        guard let context = SSL_CTX_new(TLS_server_method()) else { return nil }
        
        super.init(ctx: context)
        
        
        // Set default options
        
        SSL_CTX_set_options(optr, (UInt(SSL_OP_NO_SSLv2) + UInt(SSL_OP_NO_SSLv3) + UInt(SSL_OP_ALL)))
    }
}


/// A context for a client.

public final class ClientCtx: Ctx {
    
    /// Creates a new ClientCtx.
    ///
    /// If the creations fails, the SecureSockets.errPrintErrors may have more information on the cause.
    
    public init?() {
        
        ERR_clear_error()
        
        
        // Create client context
        
        guard let context = SSL_CTX_new(TLS_client_method()) else { return nil }
        
        super.init(ctx: context)
        
        
        // Set default options
        
        SSL_CTX_set_options(optr, (UInt(SSL_OP_NO_SSLv2) + UInt(SSL_OP_NO_SSLv3) + UInt(SSL_OP_ALL)))
    }
}
