using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ObjectRotation : MonoBehaviour
        {
           public float rotateSpeed = 5.0f; // 旋转速度
    private Vector2 lastPosition; // 上一帧的触摸位置
            void Update()
            {
                if (Input.touchCount == 1) // 检测是否单指触摸
        {
            Touch touch = Input.GetTouch(0);
            if (touch.phase == TouchPhase.Moved) // 检测是否在移动状态
            {
                Vector2 currentPosition = touch.position;
                float deltaX = currentPosition.x - lastPosition.x; // 计算当前触摸位置与上一帧触摸位置之间的X轴位移
                float rotationAmount = -deltaX * rotateSpeed * Time.deltaTime; // 计算旋转量，乘以deltaTime确保旋转速度平滑
                transform.Rotate(0, rotationAmount,0 ); // 围绕x轴旋转物体
                lastPosition = currentPosition; // 更新上一帧触摸位置
            }
            else if (touch.phase == TouchPhase.Began) // 如果是开始触摸，则记录下触摸位置
            {
                lastPosition = touch.position;
            }
        }
        
    
        transform.Rotate(Vector3.up*Time.deltaTime*rotateSpeed);

            }
        }
        