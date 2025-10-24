-- =============================================
-- Supabase 데이터베이스 오류 수정 SQL
-- =============================================

-- 1. handle_new_user 함수 수정 (org, phone 필드 추가)
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, name, org, phone)
    VALUES (
        NEW.id, 
        NEW.email, 
        COALESCE(NEW.raw_user_meta_data->>'name', '사용자'),
        NEW.raw_user_meta_data->>'org',
        NEW.raw_user_meta_data->>'phone'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. profiles 테이블에 INSERT 권한 추가 (RLS 정책)
-- 기존 INSERT 정책이 없으므로 추가
CREATE POLICY "사용자는 자신의 프로필 생성 가능" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 3. auth.users 테이블에 대한 INSERT 권한 확인
-- (이미 Supabase에서 자동으로 처리되지만 명시적으로 확인)

-- 4. profiles 테이블의 user_type 기본값 설정 개선
ALTER TABLE profiles ALTER COLUMN user_type SET DEFAULT 'user';

-- 5. 이메일 중복 체크 비활성화 (Supabase Auth가 처리)
-- 기존 unique 제약 조건이 있다면 제거
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_email_key;

-- 6. 디버깅을 위한 로그 함수 추가
CREATE OR REPLACE FUNCTION log_user_creation()
RETURNS TRIGGER AS $$
BEGIN
    RAISE LOG 'Creating profile for user: %, email: %, org: %, phone: %', 
        NEW.id, NEW.email, NEW.org, NEW.phone;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. 디버깅 트리거 추가 (선택사항)
DROP TRIGGER IF EXISTS log_profile_creation ON profiles;
CREATE TRIGGER log_profile_creation
    BEFORE INSERT ON profiles
    FOR EACH ROW EXECUTE FUNCTION log_user_creation();

-- 8. 기존 문제가 있는 데이터 정리 (선택사항)
-- 이메일이 중복된 경우 처리
UPDATE profiles 
SET email = email || '_duplicate_' || extract(epoch from created_at)
WHERE id IN (
    SELECT id FROM profiles 
    WHERE email IN (
        SELECT email FROM profiles 
        GROUP BY email HAVING COUNT(*) > 1
    )
);

-- 9. 테스트용 관리자 계정 생성 (선택사항)
-- 실제 사용 시에는 제거하세요
INSERT INTO profiles (id, email, name, org, phone, user_type)
VALUES (
    '00000000-0000-0000-0000-000000000000',
    'admin@example.com',
    '관리자',
    '시스템',
    '010-0000-0000',
    'admin'
) ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    org = EXCLUDED.org,
    phone = EXCLUDED.phone,
    user_type = EXCLUDED.user_type;

-- 10. 권한 확인 쿼리
-- 다음 쿼리들을 실행해서 권한이 제대로 설정되었는지 확인하세요:

-- RLS가 활성화되어 있는지 확인
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'profiles';

-- profiles 테이블의 정책들 확인
SELECT policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'profiles';

-- 현재 사용자 권한 확인
SELECT current_user, session_user;

-- =============================================
-- 실행 후 확인사항:
-- 1. Supabase Dashboard에서 Authentication > Users 확인
-- 2. Table Editor에서 profiles 테이블 확인
-- 3. 로그에서 오류 메시지 확인
-- =============================================
