const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

const AUP_RFID_LOOKUP_URL = "https://a.aolis.aup.edu.ph/personal/sheepcounter/rfidwho.php?s=";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(request.url);
    const scannedValue = String(url.searchParams.get("s") || "").trim();

    if (!scannedValue) {
      return new Response("Missing RFID or ID number.", {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "text/plain; charset=utf-8",
        },
      });
    }

    const lookupResponse = await fetch(`${AUP_RFID_LOOKUP_URL}${encodeURIComponent(scannedValue)}`, {
      method: "GET",
      headers: {
        Accept: "text/plain, text/html, application/json;q=0.9, */*;q=0.8",
      },
    });

    const body = await lookupResponse.text();

    return new Response(body, {
      status: lookupResponse.ok ? 200 : lookupResponse.status,
      headers: {
        ...corsHeaders,
        "Content-Type": lookupResponse.headers.get("Content-Type") || "text/plain; charset=utf-8",
        "Cache-Control": "no-store",
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "RFID lookup failed.";

    return new Response(message, {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "text/plain; charset=utf-8",
      },
    });
  }
});
