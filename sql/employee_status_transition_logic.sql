-- ========================================
-- SQLファイル: employee_status_transition_logic.sql
-- 目的:
--   社員ステータスの業務遷移（現役→休職、退職→現役復帰）を
--   トランザクション付きで実行するロジックを定義する。
--
-- 前提:
--   - MySQL 8 系で実行すること
--   - employee.employee_status_id
--       1: 現役社員
--       2: 休職社員
--       3: 退職社員
--
-- 使い方（例）:
--   CALL employee.transition_active_to_leave(1, DATE '2026-04-01', NULL);
--   CALL employee.transition_retired_to_active(5, DATE '2026-05-01');
-- ========================================

USE employee;

DELIMITER $$

DROP PROCEDURE IF EXISTS transition_active_to_leave$$
CREATE PROCEDURE transition_active_to_leave(
  IN p_employee_id INT,
  IN p_leave_date DATE,
  IN p_leave_company_email VARCHAR(256)
)
BEGIN
  DECLARE v_current_status INT;
  DECLARE v_employee_contact_information_id INT;
  DECLARE v_company_email VARCHAR(256);

  -- SQL実行中にエラーが出たら、途中更新を残さず全体をロールバックする。
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  -- 対象社員の行をロックし、同時更新を防ぐ。
  SELECT e.employee_status_id
    INTO v_current_status
  FROM employee AS e
  WHERE e.employee_id = p_employee_id
  FOR UPDATE;

  IF v_current_status IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'employee not found';
  END IF;

  IF v_current_status <> 1 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'only active employee can move to leave';
  END IF;

  -- 1) 社員ステータスを「休職」に更新
  UPDATE employee
  SET employee_status_id = 2
  WHERE employee_id = p_employee_id;

  -- 2) 休職イベントを記録（同日重複は抑止）
  INSERT INTO leave_of_absence(employee_id, leave_of_absence_date)
  SELECT p_employee_id, p_leave_date
  WHERE NOT EXISTS (
    SELECT 1
    FROM leave_of_absence lo
    WHERE lo.employee_id = p_employee_id
      AND lo.leave_of_absence_date = p_leave_date
  );

  -- 3) 休職連絡先を補完
  --    active_employee_contact_information から連絡先IDと社用メールを取得し、
  --    contact_information_for_staff_on_leave に反映する。
  SELECT
    aeci.employee_contact_information_id,
    aeci.company_email
    INTO v_employee_contact_information_id, v_company_email
  FROM active_employee_contact_information AS aeci
  INNER JOIN employee_contact_information AS eci
    ON eci.employee_contact_information_id = aeci.employee_contact_information_id
  WHERE eci.employee_id = p_employee_id
  ORDER BY aeci.active_employee_contact_information_id
  LIMIT 1;

  IF v_employee_contact_information_id IS NOT NULL THEN
    INSERT INTO contact_information_for_staff_on_leave(
      employee_contact_information_id,
      company_email
    )
    SELECT
      v_employee_contact_information_id,
      COALESCE(p_leave_company_email, v_company_email)
    WHERE NOT EXISTS (
      SELECT 1
      FROM contact_information_for_staff_on_leave cisl
      WHERE cisl.employee_contact_information_id = v_employee_contact_information_id
    );
  END IF;

  COMMIT;
END$$

DROP PROCEDURE IF EXISTS transition_retired_to_active$$
CREATE PROCEDURE transition_retired_to_active(
  IN p_employee_id INT,
  IN p_reinstatement_date DATE
)
BEGIN
  DECLARE v_current_status INT;
  DECLARE v_returning_permission BOOLEAN;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  -- 対象社員をロックしてステータス確認
  SELECT e.employee_status_id
    INTO v_current_status
  FROM employee AS e
  WHERE e.employee_id = p_employee_id
  FOR UPDATE;

  IF v_current_status IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'employee not found';
  END IF;

  IF v_current_status <> 3 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'only retired employee can move to active';
  END IF;

  -- 退職社員テーブルに復帰可否がある場合は、最新値でチェック
  SELECT re.returning_permission
    INTO v_returning_permission
  FROM retired_employee AS re
  WHERE re.employee_id = p_employee_id
  ORDER BY re.retired_employee_id DESC
  LIMIT 1;

  IF v_returning_permission IS NOT NULL AND v_returning_permission = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'returning is not permitted for this employee';
  END IF;

  -- 1) 社員ステータスを「現役」に更新
  UPDATE employee
  SET employee_status_id = 1
  WHERE employee_id = p_employee_id;

  -- 2) 復職イベントを記録（同日重複は抑止）
  INSERT INTO reinstatement(employee_id, reinstatement_date)
  SELECT p_employee_id, p_reinstatement_date
  WHERE NOT EXISTS (
    SELECT 1
    FROM reinstatement r
    WHERE r.employee_id = p_employee_id
      AND r.reinstatement_date = p_reinstatement_date
  );

  COMMIT;
END$$

DELIMITER ;
