"""
ppo-train-drone.py

드론 자율 비행 학습 코드
"""

import json
import os

import ray
from ray.rllib.agents import ppo
from ray.rllib.agents.ppo.ppo import PPOTrainer
from ray.tune.logger import pretty_print
from ray.tune.registry import register_env

#from simenv import DroneSimEnv
from simenv1 import DroneSimEnv

DEFAULT_NUM_WORKERS = 1
PWD = os.path.dirname(os.path.realpath(__file__)) + '/'
WORLDS_JSON_NAME = 'worlds.json'
WORLDS_JSON_PATH = PWD + WORLDS_JSON_NAME
MASTER_URI_JSON_PATH = PWD + 'masters.json'
CHECKPOINT_PATH_BASE = PWD + 'checkpoint/'
RESULT_CSV_NAME = "./goal_collision_data.csv"
EXIT_ON_SUCCESS = True

def main():
    """main function"""

    ray.init()

    if 'NUM_WORKERS' in os.environ:
        num_of_workers = int(os.environ['NUM_WORKERS'])
    else:
        num_of_workers = DEFAULT_NUM_WORKERS

    if os.path.isfile(WORLDS_JSON_PATH):
        with open(WORLDS_JSON_PATH) as jsonfile:
            dict_worlds = json.load(jsonfile)
    else:
        dict_worlds = None

    if os.path.isfile(MASTER_URI_JSON_PATH):
        with open(MASTER_URI_JSON_PATH) as jsonfile:
            list_master_uri = json.load(jsonfile)['master_uri']
    else:
        list_master_uri = None

    config = ppo.DEFAULT_CONFIG.copy()
    config.update({
        'env_config': {
            'dict_worlds': dict_worlds,
            'list_master_uri': list_master_uri, # 병렬 시뮬레이션 수행 스크립트 사용할 때
            # 'list_master_uri': None, # 기본 ROS 마스터 URI로 시뮬레이션 1개만 돌릴 떄
            'use_random_heading': True,
            'result_csv': RESULT_CSV_NAME,
            'num_workers': num_of_workers
            },
        'num_gpus': 0, # 사용하는 GPU 수에 맞게 설정
        'num_workers': num_of_workers,

        'train_batch_size': 10000,
        'batch_mode': 'complete_episodes'
    })

    register_env('gazebo', lambda cfg: DroneSimEnv(cfg))
    trainer = PPOTrainer(env='gazebo', config=config)
    num_iteration = 10000

    latest_index = 0
    checkpoint_path = None
    checkpoint_name = None
    for name in [name for name in os.listdir(CHECKPOINT_PATH_BASE) if 'checkpoint_' in name]:
        index = int(name.replace('checkpoint_', ''))
        if index > latest_index:
            latest_index = index
            checkpoint_path = CHECKPOINT_PATH_BASE + name + '/'
            checkpoint_name = 'checkpoint-' + str(index)
    if checkpoint_name:
        print('Running using (', checkpoint_name, ').')
        trainer.restore(checkpoint_path + checkpoint_name)

    print(checkpoint_name, '==========================================')

    ## goal/collision data init
    success_cnt = 0

    goal_rate_filename = 'goal_rate_{}.csv'.format(
        WORLDS_JSON_NAME.replace('curriculum/', '').replace('.json', ''))

    if not os.path.isfile(goal_rate_filename):
        with open(goal_rate_filename, 'w') as goal_rate_logfile:
            goal_rate_logfile.write("training_iteration,goal_rate\n")

    while True:
        ## goal/collision data create
        with open(RESULT_CSV_NAME, 'w+') as file_:
            pass

        result = trainer.train()
        print(pretty_print(result))

        # 복구용 체크포인트는 5 iteration 마다 저장
        if result['training_iteration'] % 5 == 0:
            checkpoint = trainer.save(CHECKPOINT_PATH_BASE)
            print("checkpoint saved at", checkpoint)

        # 결과 확인용 체크포인트는 100 iteration 마다 저장
        if result['training_iteration'] % 100 == 0:
            checkpoint = trainer.save()
            print("checkpoint saved at", checkpoint)

        ## goal/collision data read
        with open(RESULT_CSV_NAME, 'r') as file_:
            episodes_raw = file_.read()
            goal_list = episodes_raw.split(',')
            goal_cnt = goal_list.count('1')
            if goal_cnt == 0:
                goal_ratio = 0
            else:
                goal_ratio = goal_cnt / (goal_cnt + goal_list.count('0'))
            print('goal rate:', goal_ratio)
            with open(goal_rate_filename, 'a') as goal_rate_logfile:
                goal_rate_logfile.write(str(result['training_iteration'])
                                        +','
                                        +str(goal_ratio)
                                        +'\n')

        if goal_ratio >= 0.95:
            success_cnt += 1
            print('success in raw:', success_cnt)
        else:
            success_cnt = 0

        if success_cnt >= 5 and EXIT_ON_SUCCESS:
            if result['training_iteration'] % 5 != 0:
                checkpoint = trainer.save(CHECKPOINT_PATH_BASE)
                print("checkpoint saved at", checkpoint)
                break

        if result['training_iteration'] >= num_iteration:
            break

    print('PPO training is done.')

if __name__ == "__main__":
    main()
