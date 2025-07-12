-- Tenant oluşturmak için RPC fonksiyonu
CREATE OR REPLACE FUNCTION public.create_tenant_rpc(
  subdomain TEXT,
  name TEXT
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER -- Yetkilendirme atlama
SET search_path = public
AS $$
DECLARE
  v_role text;
  response json;
BEGIN
  -- Rolü al
  SELECT auth.jwt() ->> 'role' INTO v_role;
  
  -- Sadece super_admin rolü tenant oluşturabilir
  IF v_role != 'super_admin' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Sadece super_admin rolü yeni tenant oluşturabilir.',
      'code', 'unauthorized'
    );
  END IF;

  -- Subdomain benzersizliğini kontrol et
  IF EXISTS (SELECT 1 FROM public.tenants WHERE tenants.subdomain = create_tenant_rpc.subdomain) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Benzersizlik kuralı ihlali. Subdomain''i kontrol edin.',
      'code', 'duplicate_subdomain'
    );
  END IF;

  -- Tenant oluştur
  INSERT INTO public.tenants (subdomain, name)
  VALUES (create_tenant_rpc.subdomain, create_tenant_rpc.name);

  RETURN json_build_object(
    'success', true,
    'message', 'Tenant başarıyla oluşturuldu.',
    'data', json_build_object('subdomain', subdomain, 'name', name)
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Tenant oluşturulurken hata oluştu: ' || SQLERRM,
      'code', 'db_error'
    );
END;
$$;

-- RPC fonksiyonunun yetkilerini ayarla
REVOKE EXECUTE ON FUNCTION public.create_tenant_rpc FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_tenant_rpc TO authenticated;

-- Yorumları ekle
COMMENT ON FUNCTION public.create_tenant_rpc IS 'Super admin rolündeki kullanıcılar için yeni tenant oluşturan güvenli RPC fonksiyonu';
