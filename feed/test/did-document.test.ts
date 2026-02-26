import { describe, test, expect } from "bun:test";
import { didDocumentRoutes, SERVICE_DID, DOMAIN } from "../src/routes/did-document.js";

describe("DID Document Routes", () => {
  test("didDocumentRoutes is a valid router", () => {
    expect(didDocumentRoutes).toBeDefined();
  });

  test("SERVICE_DID follows did:web format", () => {
    expect(SERVICE_DID).toMatch(/^did:web:.+/);
    expect(SERVICE_DID).toBe(`did:web:${DOMAIN}`);
  });

  test("DOMAIN is set", () => {
    expect(DOMAIN).toBeDefined();
    expect(typeof DOMAIN).toBe("string");
    expect(DOMAIN.length).toBeGreaterThan(0);
  });

  test("DID document structure is valid", () => {
    const didDocument = {
      "@context": ["https://www.w3.org/ns/did/v1"],
      id: SERVICE_DID,
      alsoKnownAs: [],
      verificationMethod: [
        {
          id: `${SERVICE_DID}#atproto`,
          type: "Multikey",
          controller: SERVICE_DID,
        },
      ],
      service: [
        {
          id: "#bsky_fg",
          type: "BskyFeedGenerator",
          serviceEndpoint: `https://${DOMAIN}`,
        },
      ],
    };

    expect(didDocument["@context"]).toContain("https://www.w3.org/ns/did/v1");
    expect(didDocument.id).toBe(SERVICE_DID);
    expect(Array.isArray(didDocument.alsoKnownAs)).toBe(true);
    expect(Array.isArray(didDocument.verificationMethod)).toBe(true);
    expect(didDocument.verificationMethod.length).toBeGreaterThan(0);
    expect(didDocument.verificationMethod[0].id).toBe(`${SERVICE_DID}#atproto`);
    expect(didDocument.verificationMethod[0].type).toBe("Multikey");
    expect(didDocument.verificationMethod[0].controller).toBe(SERVICE_DID);
    expect(Array.isArray(didDocument.service)).toBe(true);
    expect(didDocument.service.length).toBeGreaterThan(0);
    expect(didDocument.service[0].id).toBe("#bsky_fg");
    expect(didDocument.service[0].type).toBe("BskyFeedGenerator");
    expect(didDocument.service[0].serviceEndpoint).toBe(`https://${DOMAIN}`);
  });

  test("DID document service endpoint uses HTTPS", () => {
    const serviceEndpoint = `https://${DOMAIN}`;
    expect(serviceEndpoint).toMatch(/^https:\/\//);
  });
});
