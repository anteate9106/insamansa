-- =============================================
-- 빠른 수정 SQL (핵심 문제만 해결)
-- =============================================

-- 1. handle_new_user 함수 수정 (가장 중요)
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
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Error creating profile: %', SQLERRM;
        -- 오류가 발생해도 사용자 생성은 계속 진행
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. profiles 테이블 INSERT 권한 추가
DROP POLICY IF EXISTS "사용자는 자신의 프로필 생성 가능" ON profiles;
CREATE POLICY "사용자는 자신의 프로필 생성 가능" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 3. 이메일 중복 제약 조건 제거 (Supabase Auth가 처리)
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_email_key;

-- 4. 테이블 권한 확인 및 수정
GRANT INSERT ON profiles TO authenticated;
GRANT INSERT ON profiles TO anon;
