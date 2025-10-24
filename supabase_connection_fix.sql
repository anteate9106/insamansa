-- =============================================
-- Supabase 연결 문제 해결을 위한 SQL 스크립트
-- =============================================

-- 1. 기존 정책들 정리
DROP POLICY IF EXISTS "사용자는 자신의 프로필 생성 가능" ON profiles;
DROP POLICY IF EXISTS "사용자는 자신의 프로필만 조회/수정 가능" ON profiles;
DROP POLICY IF EXISTS "관리자는 모든 프로필 조회 가능" ON profiles;

-- 2. profiles 테이블 RLS 활성화 확인
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 3. 기본 정책들 재생성
-- 사용자 프로필 생성 정책 (회원가입 시)
CREATE POLICY "Enable insert for authenticated users" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 사용자 프로필 조회 정책
CREATE POLICY "Enable read access for users based on user_id" ON profiles
    FOR SELECT USING (auth.uid() = id);

-- 사용자 프로필 수정 정책
CREATE POLICY "Enable update for users based on user_id" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- 관리자 전체 조회 정책
CREATE POLICY "Enable read access for admins" ON profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND user_type = 'admin'
        )
    );

-- 4. handle_new_user 함수 개선
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, name, org, phone, user_type)
    VALUES (
        NEW.id, 
        NEW.email, 
        COALESCE(NEW.raw_user_meta_data->>'name', '사용자'),
        NEW.raw_user_meta_data->>'org',
        NEW.raw_user_meta_data->>'phone',
        COALESCE(NEW.raw_user_meta_data->>'user_type', 'user')
    );
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Error in handle_new_user: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. 트리거 재생성
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 6. 권한 설정
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON profiles TO anon, authenticated;
GRANT ALL ON questions TO anon, authenticated;
GRANT ALL ON options TO anon, authenticated;
GRANT ALL ON tests TO anon, authenticated;
GRANT ALL ON results TO anon, authenticated;
GRANT ALL ON result_answers TO anon, authenticated;

-- 7. 테스트용 관리자 계정 생성 (개발용)
INSERT INTO profiles (id, email, name, org, phone, user_type)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'admin@test.com',
    '테스트 관리자',
    '시스템',
    '010-0000-0001',
    'admin'
) ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    org = EXCLUDED.org,
    phone = EXCLUDED.phone,
    user_type = EXCLUDED.user_type;

-- 8. 연결 테스트용 함수
CREATE OR REPLACE FUNCTION test_connection()
RETURNS TEXT AS $$
BEGIN
    RETURN 'Supabase 연결이 정상입니다. 현재 시간: ' || NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. 사용자 생성 테스트 함수
CREATE OR REPLACE FUNCTION test_user_creation(
    p_email TEXT,
    p_name TEXT,
    p_org TEXT DEFAULT '테스트',
    p_phone TEXT DEFAULT '010-0000-0000'
)
RETURNS JSON AS $$
DECLARE
    v_user_id UUID;
    v_result JSON;
BEGIN
    -- 테스트용 UUID 생성
    v_user_id := gen_random_uuid();
    
    -- 프로필 생성
    INSERT INTO profiles (id, email, name, org, phone, user_type)
    VALUES (v_user_id, p_email, p_name, p_org, p_phone, 'user');
    
    -- 결과 반환
    SELECT json_build_object(
        'success', true,
        'user_id', v_user_id,
        'message', '테스트 사용자 생성 성공'
    ) INTO v_result;
    
    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'message', '테스트 사용자 생성 실패'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. 실행 후 확인사항
-- 다음 쿼리들을 실행해서 설정이 올바른지 확인하세요:

-- RLS 활성화 확인
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'profiles';

-- 정책 확인
SELECT policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'profiles';

-- 연결 테스트
SELECT test_connection();

-- 사용자 생성 테스트
SELECT test_user_creation('test@example.com', '테스트 사용자');

-- =============================================
-- 추가 설정 (Supabase Dashboard에서)
-- =============================================

-- 1. Authentication > Settings에서 확인:
-- - Enable email confirmations: OFF (개발용)
-- - Enable phone confirmations: OFF
-- - Enable email change confirmations: OFF

-- 2. Database > Functions에서 확인:
-- - handle_new_user 함수가 정상적으로 생성되었는지 확인

-- 3. Database > Triggers에서 확인:
-- - on_auth_user_created 트리거가 정상적으로 생성되었는지 확인

-- 4. API > Settings에서 확인:
-- - Project URL과 API Key가 올바른지 확인
-- - CORS 설정이 올바른지 확인
