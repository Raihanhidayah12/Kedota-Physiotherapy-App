# Supabase Edge Functions

This directory contains Supabase Edge Functions for the Kedota Physiotherapy App.

## Available Functions

### update-pin

**Purpose:** Securely update user PIN from client (forgot PIN flow)

**Path:** `update-pin/index.ts`

**Endpoint:** `https://wwmctqhbqpsbkyxkeaqv.supabase.co/functions/v1/update-pin`

**Method:** POST

**Authentication:** Bearer token (JWT or anon key)

**Request Body:**
```json
{
  "profile_id": "uuid-of-user-profile",
  "new_pin_hash": "sha256-hash-of-new-pin",
  "new_pin": "123456"
}
```

**Response (Success):**
```json
{
  "success": true,
  "profile": { ... }
}
```

**Response (Error):**
```json
{
  "error": "Error message",
  "detail": "Detailed error information"
}
```

**Security:**
- Validates JWT tokens
- Prevents users from updating other users' PINs
- Uses service-role key safely (server-side only)
- Implements rollback on failure

**Use Cases:**
1. **Forgot PIN flow** - User resets PIN without active session
2. **Admin operations** - Future admin PIN reset functionality

## Deployment

### Prerequisites
- Supabase CLI installed: `npm install -g supabase`
- Project linked: `supabase link --project-ref wwmctqhbqpsbkyxkeaqv`

### Deploy All Functions
```bash
supabase functions deploy
```

### Deploy Specific Function
```bash
supabase functions deploy update-pin
```

### List Deployed Functions
```bash
supabase functions list
```

### View Function Logs
```bash
supabase functions logs update-pin
```

Or view in dashboard:
https://supabase.com/dashboard/project/wwmctqhbqpsbkyxkeaqv/logs/edge-functions

## Local Development

### Run Function Locally
```bash
supabase functions serve update-pin
```

### Test Locally
```bash
curl -X POST http://localhost:54321/functions/v1/update-pin \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "profile_id": "test-user-id",
    "new_pin_hash": "test-hash",
    "new_pin": "123456"
  }'
```

## Environment Variables

Edge Functions have access to these environment variables automatically:
- `SUPABASE_URL` - Your project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (secure)
- `SUPABASE_ANON_KEY` - Anonymous key

No additional configuration needed!

## Adding New Functions

1. **Create function directory:**
   ```bash
   mkdir supabase/functions/my-new-function
   ```

2. **Create index.ts:**
   ```typescript
   import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
   
   Deno.serve(async (req) => {
     // Your function code here
   });
   ```

3. **Deploy:**
   ```bash
   supabase functions deploy my-new-function
   ```

## Best Practices

1. **Always validate input:**
   ```typescript
   if (!requiredField) {
     return new Response(
       JSON.stringify({ error: "Missing required field" }),
       { status: 400 }
     );
   }
   ```

2. **Handle CORS:**
   ```typescript
   const corsHeaders = {
     "Access-Control-Allow-Origin": "*",
     "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
   };
   
   if (req.method === "OPTIONS") {
     return new Response("ok", { headers: corsHeaders });
   }
   ```

3. **Use service-role client carefully:**
   ```typescript
   const supabaseAdmin = createClient(
     Deno.env.get("SUPABASE_URL")!,
     Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
     { auth: { autoRefreshToken: false, persistSession: false } }
   );
   ```

4. **Log errors for debugging:**
   ```typescript
   console.error("Operation failed:", error);
   ```

5. **Return proper HTTP status codes:**
   - 200: Success
   - 400: Bad request (invalid input)
   - 401: Unauthorized (missing/invalid token)
   - 403: Forbidden (valid token, but not allowed)
   - 404: Not found
   - 500: Internal server error

## Troubleshooting

### Function not found
- Verify deployment: `supabase functions list`
- Redeploy: `supabase functions deploy update-pin`

### 401 Unauthorized
- Check Authorization header
- Verify JWT token is valid
- Ensure anon key is correct

### 500 Internal Server Error
- Check function logs in Supabase Dashboard
- Verify environment variables are set
- Test locally to reproduce error

### CORS errors
- Ensure corsHeaders are included in all responses
- Handle OPTIONS preflight requests
- Check browser console for specific CORS error

## Monitoring

### View Logs
**Dashboard:** Supabase Dashboard → Logs → Edge Functions

**CLI:**
```bash
supabase functions logs update-pin --follow
```

### Metrics
- Request count
- Error rate
- Average response time
- Memory usage

### Alerts
Set up alerts in Supabase Dashboard for:
- High error rate
- Slow response times
- Function failures

## Resources

- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Deno Documentation](https://deno.land/manual)
- [Supabase JS Client](https://supabase.com/docs/reference/javascript/introduction)

---

**For deployment instructions, see:** `../DEPLOY_EDGE_FUNCTION.md`
