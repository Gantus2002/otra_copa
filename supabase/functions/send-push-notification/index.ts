import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type SendPushBody = {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
};

async function getAccessToken(): Promise<string> {
  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountJson) {
    throw new Error("Falta FIREBASE_SERVICE_ACCOUNT_JSON");
  }

  const serviceAccount = JSON.parse(serviceAccountJson);

  const now = Math.floor(Date.now() / 1000);
  const jwtHeader = {
    alg: "RS256",
    typ: "JWT",
  };

  const jwtClaimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: serviceAccount.token_uri,
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();

  const toBase64Url = (input: Uint8Array | string) => {
    const bytes = typeof input === "string" ? encoder.encode(input) : input;
    let binary = "";
    for (const byte of bytes) {
      binary += String.fromCharCode(byte);
    }
    return btoa(binary)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  };

  const unsignedToken =
    `${toBase64Url(JSON.stringify(jwtHeader))}.${toBase64Url(JSON.stringify(jwtClaimSet))}`;

  const privateKeyPem = serviceAccount.private_key as string;
  const pemContents = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(unsignedToken),
  );

  const jwt = `${unsignedToken}.${toBase64Url(new Uint8Array(signature))}`;

  const tokenResponse = await fetch(serviceAccount.token_uri, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body:
      `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(`No se pudo obtener access token: ${errorText}`);
  }

  const tokenJson = await tokenResponse.json();
  return tokenJson.access_token;
}

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");

    if (!supabaseUrl || !serviceRoleKey || !firebaseProjectId) {
      throw new Error("Faltan secrets requeridos");
    }

    const payload = (await req.json()) as SendPushBody;

    if (!payload.userId || !payload.title || !payload.body) {
      return Response.json(
        { error: "userId, title y body son obligatorios" },
        { status: 400 },
      );
    }

    const profileResponse = await fetch(
      `${supabaseUrl}/rest/v1/profiles?id=eq.${payload.userId}&select=fcm_token`,
      {
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      },
    );

    if (!profileResponse.ok) {
      const text = await profileResponse.text();
      throw new Error(`No se pudo leer el profile: ${text}`);
    }

    const profiles = await profileResponse.json();
    const fcmToken = profiles?.[0]?.fcm_token;

    if (!fcmToken) {
      return Response.json({
        success: false,
        message: "El usuario no tiene fcm_token",
      });
    }

    const accessToken = await getAccessToken();

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: {
              title: payload.title,
              body: payload.body,
            },
            data: payload.data ?? {},
          },
        }),
      },
    );

    const fcmResult = await fcmResponse.text();

    if (!fcmResponse.ok) {
      throw new Error(`Error FCM: ${fcmResult}`);
    }

    return Response.json({
      success: true,
      result: JSON.parse(fcmResult),
    });
  } catch (error) {
    return Response.json(
      {
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      },
      { status: 500 },
    );
  }
});